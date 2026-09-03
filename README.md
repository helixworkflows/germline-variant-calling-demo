# Helix Workflows - Germline Variant Calling Demo

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/taylordgenes/variant_calling)
[![GitHub Actions CI Status](https://github.com/taylordgenes/variant_calling/actions/workflows/nf-test.yml/badge.svg)](https://github.com/taylordgenes/variant_calling/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/taylordgenes/variant_calling/actions/workflows/linting.yml/badge.svg)](https://github.com/taylordgenes/variant_calling/actions/workflows/linting.yml)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)
[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.4.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.4.1)

## Introduction

**Helix Workflows Germline Variant Calling Demo** is a Nextflow DSL2 pipeline for germline variant calling from Illumina whole-genome sequencing (WGS) data.
It takes paired-end FASTQ files as input, performs read-level quality control, alignment, and sample-level QC, and produces small variant (SNV/indel) and structural variant (SV) calls with functional annotation.

The pipeline is built using nf-core modules, follows nf-core best practices for reproducibility and portability, and optionally supports benchmarking against Genome in a Bottle (GIAB) truth sets to evaluate variant calling performance.

## Pipeline overview

The default workflow includes the following steps:

1. Read quality control (FastQC)
2. Adapter trimming and read filtering (fastp)
3. Alignment to the reference genome (BWA-MEM2)
4. Duplicate marking and alignment metrics (Picard)
5. Coverage and depth QC (mosdepth)
6. Contamination estimation (VerifyBamID2)
7. Sample identity, sex inference, and ancestry checks (Somalier)
8. Small variant calling (SNVs and indels) (DeepVariant)
9. Structural variant calling (Manta, TIDDIT)
10. Variant annotation (Ensembl VEP)
11. Aggregated reporting (MultiQC)

Optional benchmarking against GIAB truth data can be enabled via a dedicated pipeline profile.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
```

Each row represents a pair of fastq files (paired end).

Now, you can run the pipeline using:

```bash
nextflow run taylordgenes-variant-calling/main.nf \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --genome GRCh38 \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Documentation

This pipeline includes extended documentation describing the selected tools, benchmarking strategy, and pipeline construction.

### Benchmarking

[Benchmarking](docs/benchmarking.md)

Details the benchmarking framework used to evaluate small-variant calling performance using Genome in a Bottle (GIAB) truth sets.
It documents the normalization and comparison steps (bcftools norm and hap.py), the reference datasets used (HG002, GRCh38), and the interpretation of precision, recall, and F1-score metrics.
Benchmarking can be enabled via a dedicated pipeline profile and is designed to support validation and method comparison.

## Credits

taylordgenes-variant-calling was originally written by Taylor Lynch.

This pipeline builds upon the work of the nf-core community and reuses a large number of nf-core modules and utilities.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
