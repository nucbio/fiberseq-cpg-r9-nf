#!/usr/bin/env bash
#SBATCH --job-name=fiberseq-r9-cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2                  # Nextflow head job only; tasks are own Slurm jobs
#SBATCH --mem=8G
#SBATCH --time=7-00:00:00                  # must outlive all task jobs incl. queue time
#SBATCH --output=%x-%j.out

# CPU part of fiberseq-cpg-r9-nf, starting from the guppy output of
# fiberseq-r9-gpu.sh (--basecalled_dir): guppy_barcoder, then per barcode
# minimap2, nanopolish CpG calls and statistics.
# Nextflow submits every task as its own Slurm job (-profile slurm); resources
# per task come from conf/base.config in the pipeline.

set -euo pipefail

# ============================================================
# Settings

# Raw FAST5 data of the same run (nanopolish needs the raw signal)
FAST5_DIR="/path/to/run/fast5"

# Guppy output copied from the GPU cluster (pass/ + sequencing_summary.txt)
BASECALLED_DIR="/path/to/results/basecaller"

# Apptainer image
CONTAINER="/path/to/fiberseq-cpg-r9_vX.Y.Z.sif"

# Output folder: results, work/, resume cache and log all go here
OUTDIR="/path/to/results"

# Reference genome (.fa or .fa.gz, absolute path or URL). Bundled yeast S288C R64-4-1:
REFERENCE="/path/to/genome.fa"

# Barcodes: 'all' (skips barcodes with < min_reads) or e.g. 'barcode01,barcode02'
BARCODES="all"

# Slurm for the task jobs
CPU_PARTITION="barnard"

# Pipeline from GitHub
PIPELINE="nucbio/fiberseq-cpg-r9-nf"
REVISION="main"                  # branch, tag or commit

# Software (adapt to your cluster)
# module load nextflow
# module load apptainer

# ============================================================

# RUN
nextflow run "${PIPELINE}" -r "${REVISION}" -latest \
    -profile slurm,apptainer \
    --container "${CONTAINER}" \
    --fast5_dir "${FAST5_DIR}" \
    --basecalled_dir "${BASECALLED_DIR}" \
    --reference "${REFERENCE}" \
    --barcodes "${BARCODES}" \
    --outdir "${OUTDIR}" \
    --slurm_queue "${CPU_PARTITION}"
