include { BCFTOOLS_NORM } from '../../../modules/nf-core/bcftools/norm/main'
include { HAPPY_HAPPY   } from '../../../modules/nf-core/happy/happy/main'

workflow RUN_BENCHMARKING {

  take:
    ch_query_vcf
    ch_fasta
    ch_fasta_fai

  main:
    // Truth inputs
    ch_truth_vcf = Channel.fromPath(params.bench_truth_vcf, checkIfExists: true)
                    .map { v -> [ [id:'truth'], v ] }

    ch_truth_bed = Channel.fromPath(params.bench_truth_bed, checkIfExists: true)
                    .map { b -> [ [id:'truth_regions'], b ] }

    // Normalize query VCF
    BCFTOOLS_NORM(
      ch_query_vcf.map { meta, vcf -> [ meta, vcf, [] ] },
      ch_fasta
    )
    ch_norm_query_vcf = BCFTOOLS_NORM.out.vcf

    // Build hap.py input tuple:
    // tuple val(meta), path(query_vcf), path(truth_vcf), path(regions_bed), path(targets_bed)
    ch_happy_input = ch_norm_query_vcf
      .combine(ch_truth_vcf)
      .combine(ch_truth_bed)
      .map { tup -> [ meta, query_vcf, truth_vcf, regions, [] ] }

    HAPPY_HAPPY(
      ch_happy_input,
      ch_fasta,
      ch_fasta_fai,
      [],
      [],
      []
    )

  emit:
    summary_csv  = HAPPY_HAPPY.out.summary_csv
    extended_csv = HAPPY_HAPPY.out.extended_csv
    versions     = BCFTOOLS_NORM.out.versions.mix(HAPPY_HAPPY.out.versions)
}
