// Unpack a gzip/bgzip reference (genome.fa.gz -> genome.fa) and check it is FASTA.
process PREPARE_REFERENCE {
    tag "${ref_gz.name}"

    input:
    path ref_gz

    output:
    path "${ref_gz.baseName}", emit: fasta

    script:
    """
    gzip -cd ${ref_gz} > ${ref_gz.baseName}
    if [ "\$(head -c 1 ${ref_gz.baseName})" != ">" ]; then
        echo "ERROR: --reference is not a FASTA file after unpacking: ${ref_gz.name}" >&2
        exit 1
    fi
    """

    stub:
    """
    printf '>chrA\\nACGT\\n' > ${ref_gz.baseName}
    """
}
