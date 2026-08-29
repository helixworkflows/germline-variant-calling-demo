# taylordgenes-variant-calling: Building the pipeline

This document is a practical walkthrough of how **taylordgenes-variant-calling** was built using the **nf-core framework** to create the pipeline template, install and wire modules, configure reference assets, add tool-specific resources, and extend the workflow with a simple benchmarking subworkflow.

## 1. Create the pipeline from the nf-core template

### What is nf-core?

[nf-core](https://nf-co.re) is a community framework for building reproducible Nextflow pipelines. It provides:

- A standardized pipeline template (project layout, CI, docs, linting, configs)
- A curated module repository of reusable DSL2 processes
- Schema-based parameter definitions and validation
- Best-practice defaults for containers, conda, and documentation

Using nf-core allows you to focus on pipeline logic instead of reinventing scaffolding.

### Create a new pipeline

Use `nf-core create` to generate a pipeline skeleton:

```bash
nf-core create
```

During the interactive prompts:

- Provide a pipeline name (e.g., `taylordgenes-variant-calling`)
- Choose a description and author details
- Keep the recommended options toggled on (CI, linting, nf-test, schema support, docs structure)

These options are helpful because they give you:

- Automated linting and formatting enforcement
- Unit testing via `nf-test`
- Parameter validation through a Nextflow schema
- Standardized documentation structure from day one

The base template also includes initial modules for **FastQC** and **MultiQC**, which makes it easy to validate your setup with a minimal working pipeline early.

## 2. Install nf-core modules used by the pipeline

With the template created, the next step is to install the nf-core DSL2 modules for each tool you want in the workflow.

Install the modules using `nf-core modules install <module>`:

```bash
nf-core modules install fastp
nf-core modules install bwamem2/mem
nf-core modules install picard/markduplicates
nf-core modules install picard/collectwgsmetrics
nf-core modules install mosdepth
nf-core modules install verifybamid/verifybamid2
nf-core modules install somalier/extract
nf-core modules install somalier/relate
nf-core modules install somalier/ancestry
nf-core modules install samtools/idxstats
nf-core modules install samtools/flagstat
nf-core modules install deepvariant/rundeepvariant
nf-core modules install manta/germline
nf-core modules install tiddit/sv
nf-core modules install ensemblvep/vep
```

> Tip: If you see an error about missing `pre-commit` while installing modules, install it first:
>
> ```bash
> pipx install pre-commit
> ```

## 3. Configure the test profile (test data + samplesheet)

### Use nf-core test datasets

To validate the pipeline early, point your test profile to nf-core test datasets. Example FASTQs:

- [https://github.com/nf-core/test-datasets/blob/modules/data/genomics/homo_sapiens/illumina/fastq/test_1.fastq.gz](https://github.com/nf-core/test-datasets/blob/modules/data/genomics/homo_sapiens/illumina/fastq/test_1.fastq.gz)

The pipeline test config should reference a small samplesheet using these FASTQs.

### Update `conf/test.config`

Update the `--input` path in `conf/test.config` to point to your test samplesheet, for example:

```groovy
params {
  input  = "${projectDir}/assets/samplesheet.csv"
  outdir = 'test_results'
}
```

### Add columns to the schema if needed

As you expand the samplesheet format (read groups, lanes, sample IDs, etc.), update the `nextflow_schema.json` so nf-core tooling and docs stay accurate.

## 4. Run a minimal pipeline to confirm the template works

Before adding more logic, run the pipeline in test mode to confirm that:

- Nextflow runs correctly
- Containers/conda resolve correctly
- FastQC and MultiQC complete successfully

Example:

```bash
nextflow run main.nf -profile test,docker --outdir test_results
```

At this stage, the goal is only to confirm that the pipeline infrastructure is functioning.

## 5. Add parameters to `nextflow.config` and the schema

As tools are added, define pipeline parameters in:

- `nextflow.config` (defaults)
- `nextflow_schema.json` (validation + docs)

Typical parameters added early:

- Reference genome selection (e.g., `--genome GRCh38`)
- Tool options (flags, file paths)
- Annotation resources (VEP cache/version/species)

## 6. Collect inputs and channels in the main workflow

In the primary workflow block:

1. Read the samplesheet channel (`ch_samplesheet`)
2. Build channels for reference assets (FASTA, indexes, BEDs, resources)
3. Initialize:
   - `ch_versions` for tool versions
   - `ch_multiqc_files` for all QC outputs

## 7. Wire modules into the workflow

Modules are included at the top of the workflow file:

include { FASTQC } from '../modules/nf-core/fastqc/main'

Then chained together in the workflow using consistent channel structures.

### Use empty lists for optional inputs

Many nf-core modules accept optional “extra files” channels. If you do not need them, pass empty lists:

- `[]` for optional file lists
- placeholder tuples like `[ [ id:'null' ], [] ]` where required

This is a standard approach when using generalized modules in smaller pipelines.

## 8. Add outputs to `ch_versions` and `ch_multiqc_files`

As each module runs:

- Capture the tool versions into `ch_versions`
- Add relevant outputs into `ch_multiqc_files`

This enables:

- A pipeline-wide versions report (written as YAML)
- A unified MultiQC report aggregating all supported tool outputs

## 9. Use iGenomes for reference assets

### Why use iGenomes?

iGenomes provides standardized bundles of reference files (FASTA, BWA index, dict, fai) and improves reproducibility by reducing reference ambiguity.

In the workflow you can do:

```groovy
params.fasta     = getGenomeAttribute('fasta')
params.bwa_index = getGenomeAttribute('bwa')
```

### NCBI vs GATK reference builds

Not all “GRCh38” references are identical across sources. Differences can include:

- Contigs included (alt contigs, decoys, HLA)
- Chromosome naming conventions (`chr1` vs `1`)
- Sequence dictionaries and index compatibility

Use a reference source that matches your downstream tools and benchmarking truth sets. For example, GIAB truth sets on GRCh38 typically assume a specific contig naming convention and reference build style. When integrating external truth data, reference consistency is critical.

If required files are missing, add them to `conf/igenomes.config` so they can be resolved consistently under a `--genome` selection.

## 10. Push the pipeline to GitHub

Once the pipeline is functional locally:

```bash
git remote add origin https://github.com/your-username/repo-name.git
git add .
git commit -m "Initial nf-core-based variant calling pipeline"
git push -u origin main
```

If pushing fails due to authentication, use a GitHub token (HTTPS) or configure SSH credentials properly in your environment.

## 11. Add VerifyBamID2 resource files

VerifyBamID2 requires additional resource data files, which can be obtained from the VerifyBamID repository:

- [https://github.com/Griffan/VerifyBamID/tree/master/resource](https://github.com/Griffan/VerifyBamID/tree/master/resource)

Example download:

```bash
wget https://raw.githubusercontent.com/Griffan/VerifyBamID/master/resource/1000g.phase3.100k.b38.vcf.gz.dat.mu
```

These resources are typically stored in a consistent reference directory and exposed to the workflow via parameters.

## 12. Add Somalier site files

Somalier requires a sites VCF. A common hg38 sites file is:

- [https://github.com/brentp/somalier/files/3412456/sites.hg38.vcf.gz](https://github.com/brentp/somalier/files/3412456/sites.hg38.vcf.gz)

A full Somalier data bundle is also available from Zenodo:

- [https://zenodo.org/records/5878875/files/somalier_data.tar.gz?download=1](https://zenodo.org/records/5878875/files/somalier_data.tar.gz?download=1)

Store these in a pipeline reference directory and point to them using params.

## 13. Debugging tools inside containers

When troubleshooting module behavior, it can help to enter the container interactively:

```bash
docker run --rm -it \
  -v "$PWD:/work" \
  -w /work \
  community.wave.seqera.io/library/bwa-mem2_htslib_samtools:db98f81f55b64113 \
  bash
```

This is useful for validating:

- tool availability
- file paths
- reference indexing
- exact command syntax

## 14. Build an offline VEP cache

VEP annotation requires an offline cache for reproducible runs.

Example steps:

```bash
sudo mkdir -p /data/vep/cache
sudo chown -R 1000:1000 /data/vep
```

Then run the VEP installer from the Ensembl VEP container:

```bash
docker run --rm -it \
  -u $(id -u):$(id -g) \
  -v /data/vep:/data/vep \
  ensemblorg/ensembl-vep:release_115.0 \
  bash -lc '
    perl /opt/vep/src/ensembl-vep/INSTALL.pl \
      --AUTO c \
      --SPECIES homo_sapiens \
      --ASSEMBLY GRCh38 \
      --CACHEDIR /data/vep/cache \
      --CACHE_VERSION 115 \
      --NO_HTSLIB
  '
```

This produces a directory layout that can be used by the nf-core `ensemblvep/vep` module via `--dir_cache`.

## 15. Add a simple benchmarking subworkflow

To benchmark small variants, a minimal setup can include:

- normalization with `bcftools norm`
- benchmarking with `hap.py`

Install modules:

```bash
nf-core modules install bcftools/norm
nf-core modules install happy/happy
```

### Benchmarking data (GIAB HG002, GRCh38)

Truth set and regions:

- [https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/GRCh38/](https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/GRCh38/)

Raw Illumina reads:

- [https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/reads/](https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/reads/)

This pipeline uses a benchmarking profile and a dedicated benchmarking samplesheet, allowing the benchmarking workflow to run on HG002-only inputs without modifying the main workflow structure.
