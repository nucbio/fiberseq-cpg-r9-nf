#!/usr/bin/env bash
# Whole fiberseq-cpg-r9-nf pipeline on one machine with a GPU (local executor,
# no Slurm): guppy basecalling, demultiplexing, minimap2, nanopolish CpG calls.
# Run:  ./fiberseq-r9-all.sh

set -euo pipefail

# ============================================================
# SETTINGS

# Raw FAST5 data of one run, not demultiplexed (quotes handle special characters)
FAST5_DIR="/path/to/run/fast5"

# Apptainer image
CONTAINER="/path/to/fiberseq-cpg-r9_vX.Y.Z.sif"

# Output folder: results, work/, resume cache and log all go here
OUTDIR="/path/to/results"

# Reference genome (.fa or .fa.gz, absolute path or URL). Bundled yeast S288C R64-4-1:
REFERENCE="/path/to/reference/sequence.fa"

# Barcodes: 'all' (skips barcodes with < min_reads) or e.g. "barcode01,barcode02"
BARCODES="all"

# Pipeline from GitHub
PIPELINE="nucbio/fiberseq-cpg-r9-nf"
REVISION="main"                  # branch, tag or commit

# Software (adapt to your machine)
# module load nextflow
# module load apptainer

# ============================================================

# RUN
nextflow run "${PIPELINE}" -r "${REVISION}" -latest \
    -profile local,apptainer \
    --container "${CONTAINER}" \
    --fast5_dir "${FAST5_DIR}" \
    --reference "${REFERENCE}" \
    --barcodes "${BARCODES}" \
    --outdir "${OUTDIR}"
