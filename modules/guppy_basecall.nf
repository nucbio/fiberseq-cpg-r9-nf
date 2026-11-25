// GPU part: guppy basecalling of all raw fast5 files of one (multiplexed) run.
// Fails without a GPU; --cpu uses the guppy CPU build instead (very slow).
process GUPPY_BASECALL {
    tag "${fast5_dir.name}"
    label 'gpu'
    publishDir "${params.outdir}", mode: params.publish_mode

    input:
    path fast5_dir

    output:
    path "basecaller/pass",                   emit: pass
    path "basecaller/sequencing_summary.txt", emit: summary
    path "basecaller/*.{log,js}",             emit: logs, optional: true

    script:
    def mode = params.cpu
        ? "--num_callers 1 --cpu_threads_per_caller ${task.cpus}"
        : "--device ${params.guppy_device} ${params.guppy_args}"
    // GPU check inside the task (with -profile slurm only the task job has the GPU);
    // nvidia-smi comes from the host via apptainer --nv
    def gpu_check = params.cpu ? '' :
        'nvidia-smi -L || { echo "ERROR: no GPU visible in the task (nvidia-smi failed). Run on a GPU node, or add --cpu (very slow)." >&2; exit 1; }'
    """
    ${params.cpu ? 'export GUPPY_CPU=1' : gpu_check}
    guppy_basecaller \\
        -i ${fast5_dir} \\
        -s basecaller \\
        --recursive \\
        --config ${params.guppy_config} \\
        ${mode}
    """

    stub:
    """
    mkdir -p basecaller/pass
    printf '@r1 runid=x read=1 ch=1 start_time=2019-01-01T00:00:00Z\\nACGT\\n+\\nIIII\\n' > basecaller/pass/fastq_runid_x_0_0.fastq
    printf 'filename\\tread_id\\n' > basecaller/sequencing_summary.txt
    """
}
