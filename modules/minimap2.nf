// Map one barcode, keep primary mapped reads with MAPQ >= min_mapq
// (-F 2052 = unmapped + supplementary), sort and index.
process MINIMAP2_ALIGN {
    tag "$barcode"
    publishDir path: { "${params.outdir}/${barcode}/alignment" }, mode: params.publish_mode

    input:
    tuple val(barcode), path(fastq)
    path reference

    output:
    tuple val(barcode), path("reads_quality_above_${params.min_mapq}.bam"), path("reads_quality_above_${params.min_mapq}.bam.bai"), emit: bam

    script:
    def prefix = "reads_quality_above_${params.min_mapq}"
    """
    set -o pipefail
    minimap2 -ax map-ont -t ${task.cpus} ${reference} ${fastq} \\
        | samtools view -F ${params.sam_exclude_flags} -q ${params.min_mapq} -b - \\
        | samtools sort -@ ${task.cpus} -o ${prefix}.bam -
    samtools index -b ${prefix}.bam
    """

    stub:
    def prefix = "reads_quality_above_${params.min_mapq}"
    """
    touch ${prefix}.bam ${prefix}.bam.bai
    """
}
