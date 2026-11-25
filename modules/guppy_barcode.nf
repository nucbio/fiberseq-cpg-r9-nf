// CPU part: demultiplex the "pass" reads, merge the chunks of each barcode into
// barcodeXX.fastq and select the barcodes to analyse (one job per barcode later).
process GUPPY_BARCODE {
    tag "${pass_dir.name}"
    publishDir "${params.outdir}", mode: params.publish_mode, pattern: 'barcoder/**'
    publishDir "${params.outdir}/barcoder", mode: params.publish_mode, pattern: 'barcode_read_counts.tsv'

    input:
    path pass_dir

    output:
    path "selected/*.fastq",                   emit: fastq
    path "barcoder/barcoding_summary.txt",     emit: summary
    path "barcode_read_counts.tsv",            emit: counts
    path "barcoder/barcode*/barcode*.fastq",   emit: all_fastq
    path "barcoder/*.log",                     emit: logs, optional: true

    script:
    """
    guppy_barcoder \\
        --input_path ${pass_dir} \\
        --save_path barcoder \\
        --recursive \\
        --barcode_kits "${params.barcode_kits}" \\
        --worker_threads ${task.cpus} \\
        ${params.barcoder_args}

    # merge the per-chunk fastqs of each barcode into barcoder/barcodeXX/barcodeXX.fastq
    mkdir -p selected
    printf 'barcode\\treads\\tselected\\n' > barcode_read_counts.tsv
    for dir in barcoder/barcode*/; do
        bc=\$(basename "\$dir")
        find "\$dir" -name '*.fastq' ! -name "\$bc.fastq" -print0 | sort -z | xargs -0 -r cat > "\$dir/\$bc.fastq.tmp"
        mv "\$dir/\$bc.fastq.tmp" "\$dir/\$bc.fastq"
        find "\$dir" -name '*.fastq' ! -name "\$bc.fastq" -delete

        n=\$(( \$(wc -l < "\$dir/\$bc.fastq") / 4 ))
        sel=no
        if [ "${params.barcodes}" = "all" ]; then
            [ "\$n" -ge ${params.min_reads} ] && sel=yes
        else
            case ",${params.barcodes}," in *",\$bc,"*) [ "\$n" -gt 0 ] && sel=yes ;; esac
        fi
        if [ "\$sel" = yes ]; then
            ln "\$dir/\$bc.fastq" "selected/\$bc.fastq"
        fi
        printf '%s\\t%s\\t%s\\n' "\$bc" "\$n" "\$sel" >> barcode_read_counts.tsv
    done

    if [ "${params.barcodes}" != "all" ]; then
        for bc in \$(echo "${params.barcodes}" | tr ',' ' '); do
            [ -s "selected/\$bc.fastq" ] || echo "WARNING: requested \$bc has no reads" >&2
        done
    fi
    """

    stub:
    """
    mkdir -p barcoder/barcode01 barcoder/barcode02 selected
    for bc in barcode01 barcode02; do
        printf '@r1 runid=x read=1 ch=1 start_time=2019-01-01T00:00:00Z barcode=%s\\nACGT\\n+\\nIIII\\n' \$bc > barcoder/\$bc/\$bc.fastq
        ln barcoder/\$bc/\$bc.fastq selected/\$bc.fastq
    done
    touch barcoder/barcoding_summary.txt
    printf 'barcode\\treads\\tselected\\nbarcode01\\t1\\tyes\\nbarcode02\\t1\\tyes\\n' > barcode_read_counts.tsv
    """
}
