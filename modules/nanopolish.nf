// nanopolish index + call-methylation for one barcode. The index needs the raw
// fast5 directory (guppy ran without --fast5_out) and the sequencing summary.
process NANOPOLISH_METHYL {
    tag "$barcode"
    publishDir path: { "${params.outdir}/${barcode}/methylation" }, mode: params.publish_mode

    input:
    tuple val(barcode), path(fastq), path(bam), path(bai)
    path fast5_dir
    path summary
    path reference

    output:
    tuple val(barcode), path("methylation_q${params.min_mapq}.tsv"), emit: calls

    script:
    """
    # paths to the fast5 files are stored as given (fast5_dir/...), relative to this task dir
    nanopolish index -d ${fast5_dir} -s ${summary} ${fastq}

    nanopolish call-methylation \\
        -t ${task.cpus} \\
        -q ${params.motif} \\
        -r ${fastq} \\
        -b ${bam} \\
        -g ${reference} \\
        > methylation_q${params.min_mapq}.tsv
    """

    stub:
    """
    printf 'chromosome\\tstrand\\tstart\\tend\\tread_name\\tlog_lik_ratio\\tlog_lik_methylated\\tlog_lik_unmethylated\\tnum_calling_strands\\tnum_motifs\\tsequence\\n' > methylation_q${params.min_mapq}.tsv
    """
}
