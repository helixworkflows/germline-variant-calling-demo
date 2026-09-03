import csv
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "bin" / "make_qc_report.py"
SPEC = importlib.util.spec_from_file_location("make_qc_report", SCRIPT)
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


class QcReportTest(unittest.TestCase):
    def test_builds_report_and_applies_thresholds(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fastp = root / "NA12878.fastp.json"
            fastp.write_text(json.dumps({"summary": {
                "before_filtering": {"total_reads": 100},
                "after_filtering": {"total_reads": 90, "q30_rate": 0.85},
            }}))
            flagstat = root / "NA12878.flagstat"
            flagstat.write_text(
                "100 + 0 in total (QC-passed reads + QC-failed reads)\n"
                "97 + 0 mapped (97.00% : N/A)\n"
                "89 + 0 properly paired (89.00% : N/A)\n"
            )
            mosdepth = root / "NA12878.summary.txt"
            mosdepth.write_text("chrom\tlength\tbases\tmean\tmin\tmax\n"
                                "total\t100\t3100\t31\t0\t50\n")
            vcf = root / "NA12878.vcf"
            vcf.write_text("##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\n"
                           "1\t1\t.\tA\tG\t50\tPASS\n"
                           "1\t2\t.\tA\tAT\t50\tPASS\n")
            output = root / "report.csv"

            result = REPORT.main(["-o", str(output), str(fastp), str(flagstat),
                                  str(mosdepth), str(vcf)])
            self.assertEqual(result, 0)
            with output.open(newline="") as handle:
                rows = list(csv.DictReader(handle))

            values = {(row["metric"], row["status"]): row["value"] for row in rows}
            self.assertEqual(values[("Q30 bases", "PASS")], "85")
            self.assertEqual(values[("properly paired reads", "FAIL")], "89")
            self.assertEqual(values[("mosdepth mean coverage", "PASS")], "31")
            self.assertEqual(values[("total variants", "INFO")], "2")
            self.assertEqual(values[("SNVs", "INFO")], "1")
            self.assertEqual(values[("indels", "INFO")], "1")


if __name__ == "__main__":
    unittest.main()
