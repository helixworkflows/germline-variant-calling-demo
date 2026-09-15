# Helix Workflows LLC — Germline Variant Calling Demo

**Helix Workflows LLC builds production-grade bioinformatics pipelines.** This
repository demonstrates our approach through a germline variant calling workflow:
modular analysis, reproducible execution, automated testing, and clear quality
control outputs.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/helixworkflows/germline-variant-calling-demo)
[![GitHub Actions CI Status](https://github.com/helixworkflows/germline-variant-calling-demo/actions/workflows/nf-test.yml/badge.svg)](https://github.com/helixworkflows/germline-variant-calling-demo/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/helixworkflows/germline-variant-calling-demo/actions/workflows/linting.yml/badge.svg)](https://github.com/helixworkflows/germline-variant-calling-demo/actions/workflows/linting.yml)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)
[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.4.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.4.1)

## About this demo

This Nextflow DSL2 pipeline processes paired-end Illumina whole-genome sequencing
(WGS) data, from FASTQ reads through alignment, sample quality control, small
variant calling, and functional annotation. It builds on nf-core modules and
utilities, with a custom cohort QC report and optional Genome in a Bottle (GIAB)
benchmarking.

The demo shows the engineering foundations we use to build production-grade
pipelines. A production deployment brings these foundations together with the
client's data, infrastructure, acceptance criteria, and operational requirements.

## Engineering demonstrated here

| Area                    | Implementation in this repository                                                                     |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| Modular workflow design | Nextflow DSL2 processes and subworkflows built from nf-core and local modules                         |
| Reproducible execution  | Containerized tools, software version capture, and configuration profiles                             |
| Cloud execution         | An AWS Batch profile with S3 storage, Wave, and Fusion                                                |
| Automated checks        | nf-test tests, QC report output snapshots, and GitHub Actions for testing and linting                 |
| Quality control         | Read, alignment, coverage, contamination, and sample identity checks; a cohort CSV and MultiQC report |
| Performance assessment  | Optional small-variant benchmarking using GIAB truth sets, bcftools, and hap.py                       |

## Pipeline overview

1. **Read QC and filtering:** FastQC and fastp.
2. **Alignment:** BWA-MEM2 aligns reads to the reference genome.
3. **Alignment and coverage QC:** Picard marks duplicates and collects WGS metrics;
   SAMtools and mosdepth provide alignment and depth summaries.
4. **Sample QC:** VerifyBamID2 estimates contamination; Somalier supports sample
   identity, relatedness, sex, and ancestry assessment.
5. **Small variant calling:** DeepVariant calls single-nucleotide variants (SNVs)
   and small insertions and deletions (indels).
6. **Annotation:** Ensembl VEP annotates variants.
7. **Reporting:** A custom `qc_report.csv` summarizes sample metrics and threshold
   statuses; MultiQC aggregates tool reports.
8. **Optional benchmarking:** Compare small-variant calls with GIAB truth data.

Execution profiles can disable selected steps. The minimal test profile skips
contamination, Somalier, and VEP analyses to reduce the requirements for a test run.

## Run the demo

### Prerequisites

Use Nextflow 25.04.0 or later, a compatible Java installation, and an execution
environment configured for the selected profile. Review the
[usage guide](docs/usage.md) for input and reference requirements.

The supplied AWS Batch profile, test data, and several reference paths point to
Helix Workflows infrastructure. Running those configurations requires access to
those resources. For your own deployment, configure your AWS queue, IAM role,
storage locations, and reference data in the relevant configuration files.

### Prepare a samplesheet

Each row identifies one pair of FASTQ files:

```csv
sample,fastq_1,fastq_2
DEMO_SAMPLE,/path/to/sample_R1.fastq.gz,/path/to/sample_R2.fastq.gz
```

### Execute the workflow

From a local checkout configured for your environment:

```bash
nextflow run main.nf \
    -profile docker \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir results
```

Ensure the selected genome's reference files and supporting resources are
accessible before running. The Docker profile controls tool execution; reference
locations are configured separately.

With access to the configured Helix Workflows AWS environment, run the minimal demo:

```bash
nextflow run main.nf -profile test,awsbatch
```

Use `-resume` to reuse completed tasks when continuing a run. Supply analysis
parameters through the command line or a Nextflow `-params-file`, and execution
settings through configuration files.

### Run the QC report module tests locally

The QC report tests use small synthetic fixtures included in this repository.
With nf-test, Nextflow, and Python 3 installed:

```bash
nf-test test modules/local/qc_report/tests/main.nf.test --profile qc_report_local
```

These tests check cohort input, single-file input, and stub execution using output
snapshots. This command runs the QC report module tests;
the full pipeline test suite uses the repository's AWS configuration.

## Results and benchmarking

Outputs include aligned reads, small-variant calls and annotations, tool-specific
QC results, the cohort QC CSV, and a MultiQC report. See the
[output guide](docs/output.md) for details.

The optional benchmarking profile compares calls against GIAB truth sets and
reports precision, recall, and F1 scores. The
[benchmarking guide](docs/benchmarking.md) describes the datasets, comparison
steps, and interpretation. Results should be assessed in the context of the
input coverage, reference, and benchmark regions used for each run.

## Work with Helix Workflows LLC

Helix Workflows LLC builds production-grade pipelines around your analysis and
operational requirements. This repository provides a concrete starting point for
discussing workflow design, cloud execution, testing, QC, and benchmarking for
your own datasets.

To start a technical discussion, visit the
[Helix Workflows GitHub organization](https://github.com/helixworkflows).
For demo questions or reproducible problems, open a
[repository issue](https://github.com/helixworkflows/germline-variant-calling-demo/issues).

## Documentation

- [Usage and configuration](docs/usage.md)
- [Outputs](docs/output.md)
- [Benchmarking](docs/benchmarking.md)

## Credits

Developed by Taylor Lynch for Helix Workflows LLC.

This pipeline builds on the work of the nf-core community and reuses nf-core
modules and utilities. Tool authors and community contributors are acknowledged
in the citations below.

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
