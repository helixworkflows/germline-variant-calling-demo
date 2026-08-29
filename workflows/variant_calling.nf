/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { FASTP                  } from '../modules/nf-core/fastp/main'
include { BWAMEM2_MEM            } from '../modules/nf-core/bwamem2/mem/main'
include { PICARD_COLLECTWGSMETRICS} from '../modules/nf-core/picard/collectwgsmetrics/main'
include { PICARD_MARKDUPLICATES  } from '../modules/nf-core/picard/markduplicates/main'
include { MOSDEPTH               } from '../modules/nf-core/mosdepth/main'
include { VERIFYBAMID_VERIFYBAMID2} from '../modules/nf-core/verifybamid/verifybamid2/main'
include { SOMALIER_EXTRACT       } from '../modules/nf-core/somalier/extract/main'
include { SOMALIER_ANCESTRY      } from '../modules/nf-core/somalier/ancestry/main'
include { SOMALIER_RELATE        } from '../modules/nf-core/somalier/relate/main'
include { SAMTOOLS_FLAGSTAT      } from '../modules/nf-core/samtools/flagstat/main'
include { SAMTOOLS_IDXSTATS      } from '../modules/nf-core/samtools/idxstats/main'
include { DEEPVARIANT_RUNDEEPVARIANT} from '../modules/nf-core/deepvariant/rundeepvariant/main'
include { MANTA_GERMLINE         } from '../modules/nf-core/manta/germline/main'
include { TIDDIT_SV              } from '../modules/nf-core/tiddit/sv/main'
include { ENSEMBLVEP_VEP         } from '../modules/nf-core/ensemblvep/vep/main'
include { RUN_BENCHMARKING       } from '../subworkflows/local/run_benchmarking'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_variant_calling_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VARIANT_CALLING {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_fasta
    ch_fasta_fai
    ch_bwamem2
    ch_mosdepth_bed
    ch_svd
    ch_somalier_sites
    ch_labelled_somalier_files
    ch_somalier_ped
    ch_cache
    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // MODULE: Run Fastp
    //
    FASTP (
        ch_samplesheet.map { meta, reads -> [ meta, reads, [] ] },
        params.discard_trimmed_pass,
        params.save_trimmed_fail,
        params.save_merged
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.html.collect{ it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.collect{ it[1] })
    ch_versions = ch_versions.mix(FASTP.out.versions.first())

    //
    // MODULE: Run BWA-MEM2
    //
    BWAMEM2_MEM (
        FASTP.out.reads,
        ch_bwamem2,
        ch_fasta,
        params.sort_bam
    )
    ch_versions = ch_versions.mix(FASTP.out.versions.first())

    //
    // MODULE: Run Picard
    //
    PICARD_MARKDUPLICATES (
        BWAMEM2_MEM.out.bam,
        ch_fasta,
        ch_fasta_fai
    )
    ch_multiqc_files = ch_multiqc_files.mix(PICARD_MARKDUPLICATES.out.metrics.collect{ it[1] })

    ch_bam = PICARD_MARKDUPLICATES.out.bam
    ch_bai = PICARD_MARKDUPLICATES.out.bai
    ch_bam_bai = ch_bam.join(ch_bai, by: 0)

    //ch_bam_bai.view { "BAM_BAI: $it" }
    PICARD_COLLECTWGSMETRICS (
        ch_bam_bai,
        ch_fasta,
        ch_fasta_fai,
        []
    )
    ch_multiqc_files = ch_multiqc_files.mix(PICARD_COLLECTWGSMETRICS.out.metrics.collect{ it[1] })
    ch_versions = ch_versions.mix(PICARD_COLLECTWGSMETRICS.out.versions.first())

    // //
    // // MODULE: Run mosdepth
    // //
    ch_bam_bai_bed = ch_bam_bai.combine(ch_mosdepth_bed.map { meta, bed -> [bed ?: []] })
    MOSDEPTH (
        ch_bam_bai_bed,
        ch_fasta
    )
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.summary_txt.collect{ it[1] })
    ch_versions = ch_versions.mix(MOSDEPTH.out.versions.first())

    // //
    // // MODULE: Run verifybamid2
    // //
    VERIFYBAMID_VERIFYBAMID2 (
        ch_bam_bai,
        ch_svd,
        [],
        ch_fasta.map{ meta, fa -> fa }
    )
    ch_multiqc_files = ch_multiqc_files.mix(VERIFYBAMID_VERIFYBAMID2.out.self_sm.collect{ it[1] })
    ch_versions = ch_versions.mix(VERIFYBAMID_VERIFYBAMID2.out.versions.first())

    // //
    // // MODULE: Run somalier
    // //
    SOMALIER_EXTRACT (
        ch_bam_bai,
        ch_fasta,
        ch_fasta_fai,
        ch_somalier_sites
    )
    ch_versions = ch_versions.mix(SOMALIER_EXTRACT.out.versions.first())
    ch_query_somalier_files = SOMALIER_EXTRACT.out.extract
        .map { meta, som -> som }
        .collect()
        .map { list -> [ [id:'ancestry'], list ] }

    SOMALIER_ANCESTRY (
        ch_query_somalier_files,
        ch_labelled_somalier_files
    )
    ch_multiqc_files = ch_multiqc_files.mix(SOMALIER_ANCESTRY.out.html.collect{ it[1] })
    ch_versions = ch_versions.mix(SOMALIER_ANCESTRY.out.versions)

    ch_query_somalier_files_ped = ch_query_somalier_files.combine(ch_somalier_ped.map { meta, ped -> [ped ?: []] })
    SOMALIER_RELATE (
        ch_query_somalier_files_ped,
        []
    )
    ch_multiqc_files = ch_multiqc_files.mix(SOMALIER_RELATE.out.html.collect{ it[1] })
    ch_versions = ch_versions.mix(SOMALIER_RELATE.out.versions.first())

    // //
    // // MODULE: Run samtools
    // //
    SAMTOOLS_IDXSTATS (
        ch_bam_bai
    )
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_IDXSTATS.out.idxstats.collect{ it[1] })
    ch_versions = ch_versions.mix(SAMTOOLS_IDXSTATS.out.versions.first())

    SAMTOOLS_FLAGSTAT (
        ch_bam_bai
    )
    ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_FLAGSTAT.out.flagstat.collect{ it[1] })
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions.first())

    // //
    // // MODULE: Run deepvariant
    // //
    DEEPVARIANT_RUNDEEPVARIANT (
        ch_bam_bai.map { meta, bam, bai -> [ meta, bam, bai, [] ] },
        ch_fasta,
        ch_fasta_fai,
        [ [ id:'null' ], [] ],
        [ [ id:'null' ], [] ]
    )
    ch_versions = ch_versions.mix(DEEPVARIANT_RUNDEEPVARIANT.out.versions.first())

    // //
    // // MODULE: Run manta
    // //
    MANTA_GERMLINE(
        ch_bam_bai.map { meta, bam, bai -> [ meta, bam, bai, [], [] ] },
        ch_fasta,
        ch_fasta_fai,
        []
    )
    ch_versions = ch_versions.mix(MANTA_GERMLINE.out.versions.first())

    // //
    // // MODULE: Run tiddit
    // //
    TIDDIT_SV (
        ch_bam_bai,
        ch_fasta,
        ch_bwamem2
    )
    ch_versions = ch_versions.mix(TIDDIT_SV.out.versions.first())

    // //
    // // MODULE: Run VEP
    // //
    ch_vcfs = DEEPVARIANT_RUNDEEPVARIANT.out.vcf
    ENSEMBLVEP_VEP(
        ch_vcfs.map { meta, vcf -> [ meta, vcf, [] ] },
        params.genome,
        params.species,
        params.cache_version,
        ch_cache,
        ch_fasta,
        []                // extra_files (plugins/custom VCFs)
    )
    ch_versions = ch_versions.mix(ENSEMBLVEP_VEP.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'variant_calling_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    if (params.benchmarking) {
        RUN_BENCHMARKING(
            DEEPVARIANT_RUNDEEPVARIANT.out.vcf,
            ch_fasta,
            ch_fasta_fai
        )
    }

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
