#!/usr/bin/env bash
#SBATCH --job-name=fiberseq-r9-gpu
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10                 # GUPPY_BASECALL uses 8 + Nextflow head
#SBATCH --mem=40G                          # GUPPY_BASECALL uses 32G + Nextflow head
#SBATCH --time=48:00:00
#SBATCH --output=%x-%j.out

# GPU part of fiberseq-cpg-r9-nf: guppy basecalling only (--basecall_only).
# Output: ${OUTDIR}/basecaller/{pass/, sequencing_summary.txt}
# Copy that folder to the CPU cluster and run fiberseq-r9-cpu.sh there.

set -euo pipefail

# ============================================================
# Settings

# Raw FAST5 data of one run, not demultiplexed (quotes handle special characters)
FAST5_DIR="/path/to/run/fast5"

# Apptainer image
CONTAINER="/path/to/fiberseq-cpg-r9_vX.Y.Z.sif"

# Output folder: results, work/, resume cache and log all go here
OUTDIR="/path/to/results"

# Pipeline from GitHub
PIPELINE="nucbio/fiberseq-cpg-r9-nf"
REVISION="main"                  # branch, tag or commit

# Software (adapt to your cluster)
# module load nextflow
# module load apptainer

# ============================================================

# Run (local executor inside this GPU allocation)

nextflow run "${PIPELINE}" -r "${REVISION}" -latest \
    -profile local,apptainer \
    --container "${CONTAINER}" \
    --fast5_dir "${FAST5_DIR}" \
    --outdir "${OUTDIR}" \
    --basecall_only
