#!/usr/bin/env nextflow
/*
 * fiberseq-cpg-r9-nf
 * R9.4.1 fast5 (one multiplexed run)
 *   GPU: guppy basecalling
 *   CPU: guppy demultiplexing, then per barcode: minimap2 (MAPQ filter),
 *        nanopolish CpG methylation calls, read/site statistics
 */
nextflow.enable.dsl = 2

include { GUPPY_BASECALL                  } from './modules/guppy_basecall'
include { GUPPY_BARCODE                   } from './modules/guppy_barcode'
include { MINIMAP2_ALIGN                  } from './modules/minimap2'
include { READ_INFOS                      } from './modules/read_infos'
include { NANOPOLISH_METHYL               } from './modules/nanopolish'
include { METHYL_STATS                    } from './modules/methyl_stats'
include { PREPARE_REFERENCE               } from './modules/prepare_reference'

workflow {
    // container engine + image (skipped without -profile apptainer/singularity, e.g. test profile)
    def engine = workflow.containerEngine
    if (engine in ['apptainer', 'singularity']) {
        if (['bash', '-c', "command -v ${engine}"].execute().waitFor() != 0)
            error "${engine} not found in PATH (load it first, e.g. 'module load Apptainer')"
        if (params.container?.startsWith('/') && !file(params.container).exists())
            error "Container image not found: ${params.container} (build it with ./release.sh --release or containers/build.sh)"
        log.info "container: ${params.container}"
    }

    // Slurm partition for the task jobs
    if ('slurm' in workflow.profile.tokenize(',') && !params.slurm_queue)
        error "-profile slurm needs --slurm_queue (CPU partition for the task jobs)"

    if (!params.fast5_dir) error "Missing --fast5_dir (directory with the raw, not demultiplexed fast5 files)"

    fast5_dir = file(params.fast5_dir, checkIfExists: true)
    if (!fast5_dir.isDirectory()) error "--fast5_dir is not a directory: ${fast5_dir}"

    if (params.basecall_only && params.basecalled_dir)
        error "--basecall_only and --basecalled_dir exclude each other"

    // ---- GPU part: basecalling (or reuse an existing guppy output dir) ----
    if (params.basecalled_dir) {
        bc_dir     = file(params.basecalled_dir, checkIfExists: true)
        pass_dir   = channel.value(file("${bc_dir}/pass", checkIfExists: true))
        seqsummary = channel.value(file("${bc_dir}/sequencing_summary.txt", checkIfExists: true))
    } else {
        GUPPY_BASECALL(fast5_dir)
        pass_dir   = GUPPY_BASECALL.out.pass
        seqsummary = GUPPY_BASECALL.out.summary
    }

    // ---- CPU part (skipped with --basecall_only: GPU-only run) ----
    if (!params.basecall_only) {
        // reference: local path or URL to .fa / .fa.gz (gz is unpacked)
        ref_file = file(params.reference, checkIfExists: true)
        if (ref_file.name.endsWith('.gz')) {
            PREPARE_REFERENCE(ref_file)
            reference = PREPARE_REFERENCE.out.fasta.first()
        } else {
            if (ref_file.withReader { r -> r.read() } != 62)   // 62 = '>'
                error "--reference is not a FASTA file (must start with '>'): ${ref_file}"
            reference = ref_file
        }

        GUPPY_BARCODE(pass_dir)

        // one item per selected barcode: [barcodeXX, barcodeXX.fastq]
        reads = GUPPY_BARCODE.out.fastq
            .flatten()
            .map { fq -> tuple(fq.simpleName, fq) }

        MINIMAP2_ALIGN(reads, reference)

        reads_bam = reads.join(MINIMAP2_ALIGN.out.bam)   // [bc, fastq, bam, bai]

        READ_INFOS(reads_bam)

        NANOPOLISH_METHYL(reads_bam, fast5_dir, seqsummary, reference)
        METHYL_STATS(NANOPOLISH_METHYL.out.calls)

        // all_*_read_infos.tsv over all barcodes (one header, sorted by barcode)
        READ_INFOS.out.fastq_infos
            .toSortedList { a, b -> a[0] <=> b[0] }
            .flatMap { lst -> lst.collect { e -> e[1] } }
            .collectFile(name: 'all_fastq_read_infos.tsv', keepHeader: true, skip: 1, sort: false,
                         storeDir: params.outdir)
        READ_INFOS.out.bam_infos
            .toSortedList { a, b -> a[0] <=> b[0] }
            .flatMap { lst -> lst.collect { e -> e[1] } }
            .collectFile(name: 'all_bam_read_infos.tsv', keepHeader: true, skip: 1, sort: false,
                         storeDir: params.outdir)
    }
}
