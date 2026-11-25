# fiberseq-cpg-r9-nf

Nextflow (DSL2) + Apptainer pipeline for old Oxford Nanopore **R9.4.1 fast5**
runs (yeast), from raw signal to CpG methylation calls. It is a port of the
bash scripts `guppy_basecaller.sh` (GPU) + `process_barcoded_reads.sh` (CPU).

```
                    GPU                                 CPU
fast5 dir ──> guppy_basecaller ──> pass/*.fastq ──> guppy_barcoder ──> barcodeXX.fastq
   │                │                                                     │  (one job per barcode)
   │        sequencing_summary                                            ▼
   │                │                         minimap2 | samtools view -F 2052 -q 30 | sort
   │                │                                     │          ├─> read infos
   └────────────────┴──> nanopolish index + call-methylation (cpg) <──┘
                                          └─> calc_read_stats / calc_site_stats
```

## Tools (one Apptainer image)

| tool | version | source |
|---|---|---|
| ont-guppy (GPU build) | 6.5.7 | ONT CDN |
| nanopolish (+ VBZ plugin) | 0.13.2 | built from source with its pinned submodules |
| minimap2 | 2.31 | release binary |
| samtools / htslib | 1.25 | built from source |
| Python | 3.14.10 | built from source |
| pysam / numpy | 0.24.1 / 2.5.5 | pip, `containers/requirements.txt` |

The versions are the same as the Lmod modules in `/mnt/data1/tools/26.11`.
The Python helpers in `bin/` (`get_read_infos_from_{bam,fastq}.py`,
`calc_{read,site}_stats.py`) are put on `PATH` by Nextflow.

## 1. Build the container

```bash
containers/build.sh              # apptainer build --fakeroot (default)
containers/build.sh singularity
containers/build.sh apptainer --force   # rebuild over an existing .sif
```

The image holds both guppy builds (GPU and CPU). `guppy_basecaller` runs the
GPU build and stops with an error if no CUDA driver is visible (apptainer
without `--nv`, or no GPU); `GUPPY_CPU=1` selects the CPU build.
`guppy_barcoder` always runs the CPU build.

This creates `containers/fiberseq-cpg-r9_vX.Y.Z.sif` (~4 GB, not tracked by
git), where `X.Y.Z` is `manifest.version` in `nextflow.config`. To use a copy
elsewhere, pass `--container /path/fiberseq-cpg-r9_vX.Y.Z.sif`. Released images
are built by `./release.sh --release` (see [Versioning](#versioning--releases)).

## 2. Run

The input is **one directory with the raw fast5 files of a run, not yet
demultiplexed** (searched recursively).

Workstation with GPU, everything in one go:

```bash
nextflow run main.nf -profile local,apptainer \
    --fast5_dir /path/to/run/fast5 \
    --outdir results
```

Slurm (basecalling goes to the GPU partition, everything else to the CPU partition):

```bash
nextflow run main.nf -profile slurm,apptainer \
    --fast5_dir /path/to/run/fast5 \
    --slurm_queue slim18 --slurm_gpu_queue <gpu-partition>
```

No GPU at all: add `--cpu` to basecall with the guppy CPU build (much slower,
32 CPUs by default). Without `--cpu`, basecalling fails when no GPU is found.

GPU and CPU on different machines: run basecalling only on the GPU machine
with `--basecall_only` (or reuse an old guppy output):

```bash
nextflow run main.nf -profile local,apptainer \
    --fast5_dir /path/to/run/fast5 \
    --outdir results \
    --basecall_only
```

Copy `results/basecaller` to the CPU machine and start the CPU part from it
with `--basecalled_dir`, which must contain `pass/` and `sequencing_summary.txt`:

```bash
nextflow run main.nf -profile slurm,apptainer \
    --fast5_dir /path/to/run/fast5 \
    --basecalled_dir /path/to/results/basecaller \
    --barcodes barcode01,barcode02,barcode03,barcode04 \
    --slurm_queue slim18
```

`--fast5_dir` is still needed in this case, because nanopolish reads the raw signal.

### Run templates

`templates/` has ready-made run scripts. Copy one, fill in its settings block
(paths, partitions), and start it. The scripts run the pipeline straight from
GitHub (`-latest` fetches new commits of `REVISION` on every start), so the repo
does not have to be on the cluster; only the `.sif` image does. Everything
Nextflow writes goes under `OUTDIR`, so you can start a script from any folder:
`work/` (set in `nextflow.config`), `.nextflow/` (resume cache, via
`NXF_CACHE_DIR`) and `pipeline_info/nextflow.log` (via `NXF_LOG_FILE`).
`-resume` therefore depends on `OUTDIR`, not on the launch folder.
`${OUTDIR}/work` can be deleted after a successful run. Only the Slurm log of
the head job (`%x-%j.out`) lands in the folder where you ran `sbatch`.

The scripts don't check anything themselves. The pipeline checks at startup: the
input paths, the container image and apptainer/singularity in PATH, and
`--slurm_queue` with `-profile slurm`. GUPPY_BASECALL checks the GPU with
`nvidia-smi` inside the task.

| script | where | what |
|---|---|---|
| `fiberseq-r9-all.sh` | one machine with a GPU, no Slurm | whole pipeline (local executor) |
| `fiberseq-r9-gpu.sh` | GPU cluster, `sbatch` | basecalling only (`--basecall_only`) → `results/basecaller` |
| `fiberseq-r9-cpu.sh` | CPU cluster, `sbatch` | rest of the pipeline from the copied `results/basecaller` (`--basecalled_dir`); each task is its own Slurm job |

```bash
./fiberseq-r9-all.sh

sbatch fiberseq-r9-gpu.sh      # GPU cluster
rsync -av results/basecaller/ cpu-cluster:/path/to/project/results/basecaller/
sbatch fiberseq-r9-cpu.sh      # CPU cluster (needs the fast5 too)
```

Set `REFERENCE` in the all/cpu script (passed as `--reference`); the bundled
yeast S288C is in `~/.nextflow/assets/nucbio/fiberseq-cpg-r9-nf/assets/` after the first run.
Only `fiberseq-r9-gpu.sh` uses `-resume`. To continue an interrupted all/cpu run
without starting over, add `-resume` to its `nextflow run` line.

### Paths and bind mounts

- Relative paths (`--fast5_dir`, `--outdir`, `--reference`, ...) start from the
  directory where you run `nextflow run`. Absolute paths are the safest choice.
- The container sees host files at the same paths. Nextflow (`autoMounts`) mounts
  the work dir and each task's input files automatically, so a normal run needs
  no extra option.
- `--bind` is only for files that point somewhere else: if the fast5 files are
  symlinks into another tree (for example a `cp -rs` copy), mount the target tree
  too, e.g. `--bind /mnt/data1` (comma list for several). It is not a base
  directory for the other paths.
- `APPTAINER_BINDPATH` set in your shell does not reach the tasks (Nextflow starts
  the container with a clean environment); use `--bind`.

Check the workflow wiring without tools or data:

```bash
nextflow run main.nf -profile test,local -stub
```

Run the Nextflow head job in `tmux`/`screen` or in a small long-running
Slurm job. Add `-resume` to continue an interrupted run.

`work/` always goes to `<outdir>/work`. When you call `nextflow run` yourself,
`.nextflow/` and `.nextflow.log` still land in the launch directory unless you
export `NXF_CACHE_DIR=<outdir>/.nextflow` and
`NXF_LOG_FILE=<outdir>/pipeline_info/nextflow.log` first (as the templates do).

## Parameters

| param | default | |
|---|---|---|
| `--fast5_dir` | – | raw fast5 dir of one (multiplexed) run |
| `--basecalled_dir` | – | existing guppy output; skips basecalling |
| `--basecall_only` | `false` | stop after basecalling (GPU-only run) |
| `--reference` | `assets/S288C_R64-4-1_genome_roman_chr.fa` | yeast S288C R64-4-1 (chrI…chrXVI, mito); custom genome: local path or URL to `.fa` / `.fa.gz` (gzip/bgzip is unpacked) |
| `--outdir` | `results` | |
| `--guppy_config` | `dna_r9.4.1_450bps_hac.cfg` | from MinKNOW / flowcell + kit |
| `--guppy_device` | `auto` | GPU, e.g. `cuda:0` |
| `--guppy_args` | `--gpu_runners_per_device 32` | GPU mode only |
| `--cpu` | `false` | basecall with the guppy CPU build (very slow) |
| `--barcode_kits` | `EXP-NBD104 EXP-NBD114` | |
| `--barcodes` | `all` | `all` or a comma list, e.g. `barcode01,barcode02` |
| `--min_reads` | `1000` | with `all`: skip barcodes with fewer reads (misassignments) |
| `--min_mapq` | `30` | MAPQ filter, also used in output names (`_q30`) |
| `--sam_exclude_flags` | `2052` | unmapped + supplementary |
| `--motif` | `cpg` | nanopolish: `cpg`, `gpc`, `dam`, `dcm` |
| `--call_threshold` | `2.5` | log-likelihood ratio cut-off for the statistics |
| `--container` | `containers/fiberseq-cpg-r9_vX.Y.Z.sif` | the image of the last release |
| `--bind` | – | extra host dirs to mount in the container, only for symlinks pointing outside the input dirs (see above) |
| `--slurm_queue` / `--slurm_gpu_queue` | – | Slurm partitions |
| `--slurm_gpu_opts` | `--gres=gpu:1` | |

Profiles: `local` or `slurm` (executor), combined with `apptainer`,
`singularity` or `nocontainer` (tools taken from `PATH`, e.g. Lmod modules).
There is also `test`. Resources per process are set in `conf/base.config`; you
can override them with `-c my.config`.

## Output

```
results/
  basecaller/            pass/*.fastq, sequencing_summary.txt, guppy logs
  barcoder/              barcoding_summary.txt, barcode_read_counts.tsv, barcodeXX/barcodeXX.fastq
  barcodeXX/
    fastq_read_infos.tsv
    alignment/           reads_quality_above_30.bam(.bai), bam_read_infos.tsv
    methylation/         methylation_q30.tsv (nanopolish), read_stats_q30.tsv, site_stats_q30.tsv
  all_fastq_read_infos.tsv
  all_bam_read_infos.tsv
  pipeline_info/         timeline, report, trace
```

## Versioning & releases

`MAJOR.MINOR.PATCH`, stored in `manifest.version` (`nextflow.config`). Push
with `release.sh` instead of `git push`:

```bash
./release.sh -m "message"              # patch +1 (0.0.3 -> 0.0.4), commit, push
./release.sh -m "message" --minor      # minor +1, patch reset (0.0.3 -> 0.1.0)
./release.sh -m "message" --major      # major +1, minor + patch reset (0.4.3 -> 1.0.0)
./release.sh -m "message" --release    # also: build the image, tag, push the tag
```

A normal run stages all changes (`git add -A`), commits them with the given
message and pushes `main`. With `--release` it also:

1. builds `containers/fiberseq-cpg-r9_vX.Y.Z.sif` (version label set in the image:
   `apptainer inspect` shows `org.opencontainers.image.version`); on a failed
   build the version is restored and nothing is committed,
2. sets the `--container` default to that image,
3. commits `Release vX.Y.Z: message`, tags `vX.Y.Z`, pushes `main` and the tag.

So the repo tag and the image name always carry the same version. The image is
only rebuilt on `--release`; between releases the pipeline keeps using the
image of the last release. For Zenodo, create a GitHub release from the tag
(the script prints the link) and upload the `.sif` there by hand.

## Notes

- Guppy and nanopolish are deprecated by ONT, but they are the tools for
  R9.4.1 fast5 data (dorado >= 1.0 has no R9.4.1 models).
- GPU processes (label `gpu`) run with `--nv` and go to `--slurm_gpu_queue`,
  unless `--cpu` is given.
- nanopolish indexes the whole fast5 dir once per barcode (`-s` makes this
  fast); the index files stay in the work dir.
