# taylordgenes-variant-calling: Methods

This document describes the sequencing principles, data preprocessing, quality control, variant calling, and annotation strategies used in the **taylordgenes-variant-calling** pipeline. The goal of this methods documentation is to explain not only _what_ steps are performed, but _why_ each step is included and how it contributes to robust germline variant detection.

## 1. NGS Sequencing Overview

In the Human Genome Project era, most DNA sequencing was performed using **Sanger sequencing**, where a single DNA fragment was sequenced per reaction. Modern **next-generation sequencing (NGS)** platforms, such as Illumina, instead sequence **millions to billions of DNA fragments in parallel**, dramatically increasing throughput and reducing cost.

### Library preparation

Sequencing begins with library preparation. Genomic DNA is fragmented into short pieces, typically a few hundred base pairs in length. Short, known DNA sequences called **adapters** are ligated to both ends of each fragment. These adapters serve two purposes:

- They allow fragments to bind to the sequencing flow cell.
- They contain **index (barcode) sequences** that uniquely label each sample, enabling multiple samples to be pooled and sequenced together.

### Cluster generation and sequencing

Prepared libraries are loaded onto a glass **flow cell** coated with oligonucleotides complementary to the adapter sequences. Individual DNA fragments bind to the surface and undergo **clonal amplification**, producing clusters of identical molecules at fixed locations. These clusters amplify the fluorescent signal so that each base incorporation can be reliably detected.

Illumina sequencing uses **Sequencing by Synthesis (SBS)**. A primer binds to each fragment, and fluorescently labeled nucleotides (A, C, G, T) are incorporated one at a time. After each cycle, a camera records the emitted fluorescence to determine the base. The fluorescent label and blocking group are then removed, and the cycle repeats. For a 150-cycle run, this process generates a 150-base read.

### Index reads and demultiplexing

Between sequencing cycles, the instrument also reads the index sequences embedded in the adapters. These **index reads** allow downstream software to assign each read to the correct sample during **demultiplexing**.

### Paired-end sequencing

For paired-end sequencing, the DNA template is flipped and primed from the opposite adapter, producing a second read from the other end of the fragment. This generates **Read 1 and Read 2**, which together provide positional context that improves alignment accuracy and variant detection.

### FASTQ output

After sequencing, raw images are converted into base calls and **Phred quality scores**, which estimate the probability of an incorrect base call. Low-quality clusters are filtered out, and reads are demultiplexed into per-sample **FASTQ files**, which form the starting point for all downstream analysis.

## 2. Why Paired-End Reads Are Used

Paired-end sequencing provides substantial advantages for whole-genome sequencing (WGS):

- The known distance and orientation between read pairs help align reads correctly in repetitive regions.
- Paired reads can span indels, exon junctions, and structural variant breakpoints.
- If one read maps ambiguously, its mate often anchors the fragment.
- Discordant read pairs provide signals for structural variant detection.
- Duplicate marking and error detection are improved.

### Paired-end WGS insert size considerations

Typical WGS runs use **2×150 bp reads** with an average insert size of ~350 bp. This spacing avoids excessive read overlap while maximizing unique sequence coverage per fragment. A modest insert-size distribution also reduces adapter read-through and improves mapping stability across variable fragment lengths.

## 3. Pre-Processing and Read-Level Quality Control

Before alignment, raw reads undergo quality assessment and light cleanup. Two issues are most important for short-read WGS:

1. **Adapter contamination**, which introduces non-genomic bases.
2. **Low-quality tails**, which accumulate toward the 3′ end of reads.

The objective is to remove obvious artifacts without aggressively trimming high-quality data.

### FastQC assessment

**FastQC** provides an overview of read quality, including:

- Per-base sequence quality (expect high, flat medians).
- Adapter content (should be near zero).
- GC content distribution (should match genome expectations).
- Overrepresented sequences (often adapter k-mers).
- Sequence duplication levels (WGS should be diverse).

### Trimming with fastp

Trimming is performed using **fastp**, which automatically detects adapters in paired-end data, trims low-quality tails, removes short reads, and generates HTML/JSON reports. A conservative trimming strategy preserves read length while removing clear artifacts, ensuring clean input for alignment.

## 4. Alignment and Sample-Level QC

### Alignment

Cleaned reads are aligned to the reference genome using **BWA-MEM2**, a fast and accurate aligner optimized for short-read WGS. The aligner determines where each read pair best fits in the reference and assigns mapping quality scores.

### Depth and breadth

Two metrics determine whether aligned data is suitable for variant calling:

- **Depth**: average coverage per base (e.g., 30×).
- **Breadth**: fraction of the genome above a coverage threshold (e.g., ≥95% at ≥10×).

### Alignment QC tools

- **Picard MarkDuplicates** identifies PCR and optical duplicates.
- **Picard CollectWgsMetrics** reports mean coverage and coverage distribution.
- **mosdepth** provides fast, high-resolution coverage summaries.
- **VerifyBamID2** estimates contamination using population allele frequencies.
- **Somalier** confirms sample identity, sex, and relatedness.
- **samtools flagstat / idxstats** provide quick alignment sanity checks.

All QC outputs are aggregated using **MultiQC** to produce a single summary report.

## 5. Variant Calling

Once alignment and QC metrics meet expectations, variants are called from the mapped reads.

### Variant classes

- **SNVs and indels**: small sequence changes at individual loci.
- **Structural variants (SVs)**: large rearrangements (≥50 bp), including deletions, duplications, inversions, and translocations.
- **Copy-number variants (CNVs)**: dosage-altering SVs (losses or gains).

## 6. SNVs and Indels with DeepVariant

Small variants are called using **DeepVariant**, which represents candidate variant sites as image-like summaries of the read pileup and applies a neural network to predict genotypes.

DeepVariant produces both:

- A standard **VCF** for reporting.
- A **gVCF** suitable for future joint genotyping.

### Why DeepVariant is used (and why BQSR is omitted)

Traditional GATK-based pipelines rely on **Base Quality Score Recalibration (BQSR)** to correct systematic sequencing errors. BQSR was designed for earlier sequencing chemistries and likelihood models that heavily depended on calibrated base quality scores.

DeepVariant differs fundamentally. It learns sequencing and alignment error patterns directly from the read pileups and incorporates base qualities as one signal among many. Because of this, BQSR rarely improves DeepVariant results and adds unnecessary complexity, additional inputs, and compute cost. Skipping BQSR is now standard practice in DeepVariant-based WGS pipelines.

DeepVariant was selected over GATK HaplotypeCaller for this pipeline because it consistently performs well for germline SNVs and indels, requires fewer preprocessing steps, and integrates cleanly into containerized workflows. GATK remains appropriate when strict compatibility with legacy clinical pipelines is required.

## 7. Structural Variants and CNVs

Short reads cannot span large rearrangements directly, so SV detection combines multiple signals:

- Discordant read pairs
- Split reads
- Coverage shifts

**Manta** is used as the primary breakpoint-resolved SV caller. **TIDDIT** provides complementary detection based on slightly different heuristics. Overlapping calls between callers are treated as higher confidence, while unique calls are inspected manually when relevant.

## 8. Variant Annotation

Variant annotation is performed using **Ensembl Variant Effect Predictor (VEP)**. VEP annotates variants with:

- Transcript consequences (Ensembl, RefSeq)
- MANE Select and Plus Clinical transcripts
- Protein features (UniProt, InterPro)
- Population allele frequencies (gnomAD)
- Clinical assertions (ClinVar)
- Sequence Ontology consequence terms
- HGVS nomenclature

For structural variants, VEP annotates gene overlap using `SVTYPE` and `END` fields.

Optional plugins such as **LOFTEE** and **SpliceAI** can be added to refine loss-of-function and splicing impact interpretation.

## Summary

This pipeline integrates modern best practices for WGS variant discovery: conservative preprocessing, robust QC, DeepVariant-based small variant calling, complementary SV detection, and comprehensive functional annotation. Each step is designed to maximize accuracy while minimizing unnecessary complexity, producing reproducible and interpretable germline variant callsets.
