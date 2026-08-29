# taylordgenes/variant-calling: Output

## Introduction

This document describes the output produced by the pipeline. Most quality control plots and summary statistics are collected into a single MultiQC report at the end of the workflow.

The directories listed below are created inside the pipeline --outdir once the workflow has completed successfully. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using Nextflow and processes whole-genome sequencing (WGS) data using the following steps:

- FastQC – Raw read quality control
- fastp – Adapter trimming and read preprocessing
- BWA-MEM2 – Read alignment
- Picard MarkDuplicates – Duplicate marking
- Picard CollectWgsMetrics – Whole-genome coverage metrics
- mosdepth – Coverage calculation
- VerifyBamID2 – Sample contamination estimation
- Somalier – Sample identity, ancestry, and relatedness checks
- samtools – Alignment statistics
- DeepVariant – Small variant calling (SNVs and indels)
- Manta – Structural variant calling
- TIDDIT – Structural variant calling
- Ensembl VEP – Variant annotation
- MultiQC – Aggregated QC report
- Pipeline information – Execution and provenance metadata

## FastQC

\*\_fastqc.html: Interactive HTML report.

\*\_fastqc.zip: Archive containing raw FastQC metrics and plots.

FastQC provides an initial quality assessment of raw sequencing reads, including base quality distributions, GC content, adapter contamination, and overrepresented sequences.

## fastp

\*.html: Interactive trimming and QC report.

\*.json: Machine-readable QC metrics.

fastp performs adapter trimming, low-quality base trimming, and read filtering. It also produces comprehensive QC summaries that are parsed by MultiQC.

## BWA-MEM2

\*.bam: Coordinate-sorted alignment file.

\*.bai: BAM index file.

BWA-MEM2 aligns trimmed reads to the reference genome. Paired-end alignment information is retained for downstream variant calling and QC.

## Picard MarkDuplicates

\*.bam: Duplicate-marked BAM file.

\*.bai: BAM index file.

\*.metrics.txt: Duplication metrics.

Picard MarkDuplicates identifies PCR and optical duplicates to prevent inflation of coverage and variant evidence.

## Picard CollectWgsMetrics

\*.metrics.txt: Whole-genome coverage and performance metrics.

CollectWgsMetrics reports mean coverage, coverage uniformity, and the fraction of the genome covered at different depth thresholds (e.g. ≥10×, ≥20×).

## mosdepth

\*.summary.txt: Coverage summary statistics.

\*.regions.bed.gz: Per-region coverage.

\*.per-base.bed.gz: Per-base coverage (optional).

mosdepth computes fast and memory-efficient coverage statistics, useful for identifying coverage dropouts and uneven depth.

## VerifyBamID2

\*.selfSM: Contamination estimates (freemix values).

VerifyBamID2 estimates sample contamination using population allele frequencies. Elevated freemix values may indicate sample mixture or handling issues.

## Somalier

### Somalier Extract

\*.somalier: Sample fingerprint files.

### Somalier Ancestry

\*.html: Interactive ancestry inference report.

### Somalier Relate

\*.html: Relatedness and identity report.

Somalier verifies sample identity, infers ancestry, checks reported sex, and detects unexpected relatedness or sample swaps.

## samtools

### samtools idxstats

\*.idxstats: Per-chromosome read counts.

### samtools flagstat

\*.flagstat: Alignment summary statistics.

samtools provides quick sanity checks for alignment quality, mapping rate, and pairing statistics.

## DeepVariant

\*.vcf.gz: Small variant calls (SNVs and indels).

\*.vcf.gz.tbi: Tabix index.

\*.g.vcf.gz: gVCF output (optional).

DeepVariant performs highly accurate germline SNV and indel calling using a deep learning model trained on sequencing data. Base Quality Score Recalibration (BQSR) is intentionally omitted.

## Manta

\*.vcf.gz: Structural variant calls.

\*.vcf.gz.tbi: Tabix index.

Manta detects deletions, duplications, inversions, insertions, and translocations using paired-end and split-read evidence.

## TIDDIT

\*.vcf.gz: Structural variant calls.

\*.vcf.gz.tbi: Tabix index.

TIDDIT provides complementary structural variant detection based on read depth and discordant read pairs.

## Ensembl VEP

\*.vcf.gz: Annotated VCF file.

\*.vcf.gz.tbi: Tabix index.

\*.html: Summary annotation report (optional).

Ensembl Variant Effect Predictor (VEP) annotates variants with transcript consequences, MANE selections, population frequencies, and clinical context.

## MultiQC

multiqc_report.html: Interactive HTML summary report.

multiqc_data/: Parsed statistics from pipeline tools.

multiqc_plots/: Static plots exported from the report.

MultiQCa ggregates QC metrics from all supported tools into a single report, enabling rapid assessment of sample and pipeline performance.

## Pipeline information

pipeline_info/

execution_report.html

execution_timeline.html

execution_trace.txt

pipeline_dag.dot / pipeline_dag.svg

software_versions.yml

params.json

samplesheet.valid.csv

Nextflow generates detailed execution reports and provenance metadata to support reproducibility, debugging, and auditing of pipeline runs.
