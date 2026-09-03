#!/usr/bin/env python3
"""Build a tidy, sample-level QC report from germline pipeline outputs."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import sys
import zipfile
from pathlib import Path

FIELDS = ["sample", "category", "metric", "value", "unit", "threshold", "status", "source"]


def sample_name(path: Path) -> str:
    name = path.name
    for suffix in (
        ".CollectWgsMetrics.coverage_metrics", ".MarkDuplicates.metrics.txt",
        ".somalier-ancestry.tsv", ".samples.tsv", ".pairs.tsv", ".summary.txt",
        ".selfSM", ".flagstat", ".fastp.json", ".json", ".vcf.gz", ".vcf",
        "_fastqc.zip",
    ):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    return re.sub(r"(?:_R?[12]|_[12])$", "", name)


def fmt(value: object) -> str:
    return f"{value:.6g}" if isinstance(value, float) else str(value)


def add(rows, sample, category, metric, value, unit, threshold, status, source):
    rows.append({"sample": sample, "category": category, "metric": metric,
                 "value": fmt(value), "unit": unit, "threshold": threshold,
                 "status": status, "source": source.name})


def minimum(value: float, limit: float) -> str:
    return "PASS" if value >= limit else "FAIL"


def maximum(value: float, limit: float) -> str:
    return "PASS" if value <= limit else "FAIL"


def read_text(path: Path) -> str:
    opener = gzip.open if path.name.endswith(".gz") else open
    with opener(path, "rt", errors="replace") as handle:
        return handle.read()


def parse_fastqc(path, rows, args):
    with zipfile.ZipFile(path) as archive:
        summary = next((n for n in archive.namelist() if n.endswith("summary.txt")), None)
        if not summary:
            raise ValueError("summary.txt is missing from FastQC archive")
        lines = archive.read(summary).decode(errors="replace").splitlines()
    sample = sample_name(path)
    statuses = []
    for line in lines:
        fields = line.split("\t")
        if len(fields) < 2:
            continue
        status, module = fields[:2]
        statuses.append(status)
        add(rows, sample, "fastqc", module, status, "", "PASS or WARN", status, path)
    overall = "FAIL" if "FAIL" in statuses else "WARN" if "WARN" in statuses else "PASS"
    add(rows, sample, "fastqc", "overall", overall, "", "no failed modules", overall, path)


def parse_fastp(path, rows, args):
    data = json.loads(path.read_text())
    sample = sample_name(path)
    before = data.get("summary", {}).get("before_filtering", {})
    after = data.get("summary", {}).get("after_filtering", {})
    q30 = float(after.get("q30_rate", 0)) * 100
    add(rows, sample, "fastp", "Q30 bases", q30, "%", f">={args.min_q30_pct:g}%",
        minimum(q30, args.min_q30_pct), path)
    before_reads = float(before.get("total_reads", 0))
    after_reads = float(after.get("total_reads", 0))
    retained = after_reads / before_reads * 100 if before_reads else 0
    add(rows, sample, "fastp", "reads retained", retained, "%",
        f">={args.min_reads_retained_pct:g}%", minimum(retained, args.min_reads_retained_pct), path)


def picard_table(path: Path, wanted_header: str):
    lines = read_text(path).splitlines()
    for index, line in enumerate(lines[:-1]):
        if line.startswith(wanted_header):
            return dict(zip(line.split("\t"), lines[index + 1].split("\t")))
    raise ValueError(f"Picard header beginning with {wanted_header!r} was not found")


def parse_wgs(path, rows, args):
    values = picard_table(path, "GENOME_TERRITORY")
    sample = sample_name(path)
    mean = float(values["MEAN_COVERAGE"])
    add(rows, sample, "coverage", "mean coverage", mean, "x", f">={args.min_mean_coverage:g}x",
        minimum(mean, args.min_mean_coverage), path)
    if "PCT_20X" in values:
        pct = float(values["PCT_20X"]) * 100
        add(rows, sample, "coverage", "bases at 20x", pct, "%", f">={args.min_pct_20x:g}%",
            minimum(pct, args.min_pct_20x), path)


def parse_duplicates(path, rows, args):
    values = picard_table(path, "LIBRARY")
    value = float(values["PERCENT_DUPLICATION"]) * 100
    add(rows, sample_name(path), "alignment", "duplicate reads", value, "%",
        f"<={args.max_duplicate_pct:g}%", maximum(value, args.max_duplicate_pct), path)


def parse_mosdepth(path, rows, args):
    records = list(csv.DictReader(read_text(path).splitlines(), delimiter="\t"))
    total = next((r for r in records if r.get("chrom") == "total"), None)
    if total and total.get("mean"):
        value = float(total["mean"])
        add(rows, sample_name(path), "coverage", "mosdepth mean coverage", value, "x",
            f">={args.min_mean_coverage:g}x", minimum(value, args.min_mean_coverage), path)


def parse_verifybamid(path, rows, args):
    records = list(csv.DictReader(read_text(path).splitlines(), delimiter="\t"))
    if not records:
        return
    record = records[0]
    key = next((k for k in record if k.upper().lstrip("#") == "FREEMIX"), None)
    if key:
        value = float(record[key]) * 100
        sample = record.get("#SEQ_ID") or record.get("SEQ_ID") or sample_name(path)
        add(rows, sample, "contamination", "VerifyBamID2 FREEMIX", value, "%",
            f"<={args.max_freemix_pct:g}%", maximum(value, args.max_freemix_pct), path)


def parse_flagstat(path, rows, args):
    text = read_text(path)
    sample = sample_name(path)
    for label, metric, limit in (("mapped", "mapped reads", args.min_mapped_pct),
                                 ("properly paired", "properly paired reads", args.min_properly_paired_pct)):
        match = re.search(
            rf"^.*?\s{re.escape(label)}\s+\((\d+(?:\.\d+)?)%[^\n]*\)",
            text,
            re.M,
        )
        if match:
            value = float(match.group(1))
            add(rows, sample, "alignment", metric, value, "%", f">={limit:g}%",
                minimum(value, limit), path)


def parse_ancestry(path, rows, args):
    records = list(csv.DictReader(read_text(path).splitlines(), delimiter="\t"))
    for record in records:
        clean = {k.lstrip("#"): v for k, v in record.items() if k}
        sample = clean.get("sample_id") or clean.get("sample") or clean.get("name") or sample_name(path)
        for key in ("predicted_ancestry", "ancestry", "predicted_sex", "sex"):
            if clean.get(key):
                add(rows, sample, "sample identity", key.replace("_", " "), clean[key], "", "review", "INFO", path)


def parse_somalier_samples(path, rows, args):
    records = list(csv.DictReader(read_text(path).splitlines(), delimiter="\t"))
    for record in records:
        clean = {k.lstrip("#"): v for k, v in record.items() if k}
        sample = clean.get("sample_id") or clean.get("sample") or sample_name(path)
        for key in ("sex", "gt_depth_mean", "gt_depth_sd", "n_hets"):
            if clean.get(key) not in (None, ""):
                add(rows, sample, "sample identity", f"Somalier {key.replace('_', ' ')}",
                    clean[key], "", "review", "INFO", path)


def parse_vcf(path, rows, args):
    opener = gzip.open if path.name.endswith(".gz") else open
    counts = {"total variants": 0, "PASS variants": 0, "SNVs": 0, "indels": 0, "other variants": 0}
    with opener(path, "rt", errors="replace") as handle:
        for line in handle:
            if line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 7:
                continue
            ref, alts, filt = fields[3], fields[4].split(","), fields[6]
            counts["total variants"] += 1
            if filt in ("PASS", "."):
                counts["PASS variants"] += 1
            kinds = set("SNVs" if len(ref) == len(alt) == 1 else "indels" if not alt.startswith("<") else "other variants" for alt in alts)
            for kind in kinds:
                counts[kind] += 1
    for metric, value in counts.items():
        add(rows, sample_name(path), "variants", metric, value, "count", "informational", "INFO", path)


def parser_for(path: Path):
    name = path.name
    if name.endswith("_fastqc.zip"): return parse_fastqc
    if name.endswith(".json"): return parse_fastp
    if name.endswith(".CollectWgsMetrics.coverage_metrics"): return parse_wgs
    if name.endswith(".MarkDuplicates.metrics.txt"): return parse_duplicates
    if name.endswith(".summary.txt"): return parse_mosdepth
    if name.endswith(".selfSM"): return parse_verifybamid
    if name.endswith(".flagstat"): return parse_flagstat
    if name.endswith(".somalier-ancestry.tsv"): return parse_ancestry
    if name.endswith(".samples.tsv"): return parse_somalier_samples
    if (name.endswith(".vcf") or name.endswith(".vcf.gz")) and not name.endswith(".g.vcf.gz"): return parse_vcf
    return None


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("-o", "--output", type=Path, default=Path("qc_report.csv"))
    parser.add_argument("--strict", action="store_true", help="Fail on an unreadable or unrecognised input")
    parser.add_argument("--min-q30-pct", type=float, default=80)
    parser.add_argument("--min-reads-retained-pct", type=float, default=80)
    parser.add_argument("--min-mean-coverage", type=float, default=30)
    parser.add_argument("--min-pct-20x", type=float, default=95)
    parser.add_argument("--max-duplicate-pct", type=float, default=20)
    parser.add_argument("--max-freemix-pct", type=float, default=3)
    parser.add_argument("--min-mapped-pct", type=float, default=95)
    parser.add_argument("--min-properly-paired-pct", type=float, default=90)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    rows, errors = [], []
    for path in args.inputs:
        parse = parser_for(path)
        if parse is None:
            if args.strict:
                errors.append(f"{path}: unsupported input type")
            continue
        try:
            parse(path, rows, args)
        except (OSError, ValueError, KeyError, json.JSONDecodeError, zipfile.BadZipFile) as error:
            errors.append(f"{path}: {error}")
    if errors:
        print("QC report warnings:\n  " + "\n  ".join(errors), file=sys.stderr)
        if args.strict:
            return 1
    rows.sort(key=lambda row: (row["sample"], row["category"], row["metric"], row["source"]))
    with args.output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    if not rows:
        print("No supported QC metrics were found in the supplied files", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
