// Per-read tables from the merged fastq and the filtered BAM (bin/get_read_infos_*.py).
process READ_INFOS {
    tag "$barcode"
    publishDir path: { "${params.outdir}/${barcode}" }, mode: params.publish_mode,
        saveAs: { fn -> fn == 'bam_read_infos.tsv' ? "alignment/${fn}" : fn }

    input:
    tuple val(barcode), path(fastq), path(bam), path(bai)

    output:
    tuple val(barcode), path("fastq_read_infos.tsv"), emit: fastq_infos
    tuple val(barcode), path("bam_read_infos.tsv"),   emit: bam_infos

    script:
    """
    get_read_infos_from_bam.py -i ${bam} > bam_read_infos.tsv
    get_read_infos_from_fastq.py -i ${fastq} -c ${barcode} > fastq_read_infos.tsv
    """

    stub:
    """
    printf 'read_name\\tbarcode\\n${barcode}_r1\\t${barcode}\\n' > fastq_read_infos.tsv
    printf 'read_name\\tref_seq\\n${barcode}_r1\\tchrI\\n' > bam_read_infos.tsv
    """
}
