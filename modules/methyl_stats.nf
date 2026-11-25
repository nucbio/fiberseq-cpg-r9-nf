// Per-read and per-site methylation summaries (bin/calc_*_stats.py).
process METHYL_STATS {
    tag "$barcode"
    publishDir path: { "${params.outdir}/${barcode}/methylation" }, mode: params.publish_mode

    input:
    tuple val(barcode), path(calls)

    output:
    tuple val(barcode), path("read_stats_q${params.min_mapq}.tsv"), path("site_stats_q${params.min_mapq}.tsv")

    script:
    """
    calc_read_stats.py -c ${params.call_threshold} -i ${calls} > read_stats_q${params.min_mapq}.tsv
    calc_site_stats.py -c ${params.call_threshold} -i ${calls} > site_stats_q${params.min_mapq}.tsv
    """

    stub:
    """
    touch read_stats_q${params.min_mapq}.tsv site_stats_q${params.min_mapq}.tsv
    """
}
