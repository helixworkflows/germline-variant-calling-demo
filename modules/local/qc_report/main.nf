process QC_REPORT {
    tag 'cohort'
    label 'process_single'

    container 'docker.io/library/python:3.12-slim'

    input:
    path qc_files

    output:
    path 'qc_report.csv', emit: report
    path 'versions.yml',  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def inputs = qc_files instanceof List ? qc_files.join(' ') : qc_files
    """
    make_qc_report.py \\
        --output qc_report.csv \\
        ${args} \\
        ${inputs}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """

    stub:
    """
    echo 'sample,category,metric,value,unit,threshold,status,source' > qc_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: stub
    END_VERSIONS
    """
}
