#!/usr/bin/env bash

# Data path
export INPUT="/nesi/nobackup/uoa03941/biobakery-workforce/testdata/*_R[12]_001.fastq.gz"
export OUTPUT="/nesi/nobackup/uoa03941/biobakery-workforce/work"

# Executor
export EXECUTOR="srun --account uoa03941"
#export EXECUTOR="bash"

# Add project paths to PATH
export PATH="code:$PATH"

# Apptainer
export APPTAINER_CACHEDIR="$PWD/images"
export APPTAINER_TMPDIR="$PWD/images_tmpdir"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

# Kneaddata
export KNEADDATA_CONTAINER_URL="biobakery/kneaddata:latest"
#export KNEADDATA_DB_DIR="/nesi/nobackup/uoa03941/databases/kneaddata_db"
export KNEADDATA_DB_DIR="/nesi/nobackup/uoa03941/genomes"
export KNEADDATA_DB="human_genome"
export KNEADDATA_ENV="apptainer exec --cleanenv -B $PWD:/data -B $(realpath $KNEADDATA_DB_DIR):$(realpath $KNEADDATA_DB_DIR) docker://$METAPHLAN_CONTAINER_URL"
#export KNEADDATA_ENV="docker run --rm -v $PWD:/data -w /data $KNEADDATA_URL"
#export KNEADDATA_ENV=""
export KNEADDATA_RES="--cpus-per-task=4 --mem=20G --time=06:00:00 --output=$OUTPUT/logs/kneaddata/%x_%j.out"

# Metaphlan
#export METAPHLAN_URL="depot.galaxyproject.org/singularity/metaphlan:4.2.4--pyhdfd78af_0"
export METAPHLAN_CONTAINER_URL="quay.io/biocontainers/metaphlan:4.2.4--pyhdfd78af_0"
export METAPHLAN_DB_DIR="/nesi/nobackup/uoa03941/databases/databases"
#export METAPHLAN_DB="mpa_vJan25_CHOCOPhlAnSGB_202503" too new for hum3.9 to handle, 4 is not docker yet
export METAPHLAN_DB="mpa_vJun23_CHOCOPhlAnSGB_202307"
export METAPHLAN_ENV="apptainer exec --cleanenv -B $PWD:/data -B $(realpath $METAPHLAN_DB_DIR):$(realpath $METAPHLAN_DB_DIR) docker://$METAPHLAN_CONTAINER_URL"
#export METAPHLAN_ENV="docker run --rm -v $PWD:/data -w /data $METAPHLAN_CONTAINER_URL"
#export METAPHLAN_ENV=""
export METAPHLAN_RES="--cpus-per-task=8 --mem=48G --time=03:00:00 --output=$OUTPUT/logs/metaphlan/%x_%j.out"

# Humann
export HUMANN_CONTAINER_URL="quay.io/biocontainers/humann:3.9--py312hdfd78af_0"
export HUMANN_DB_DIR="/nesi/nobackup/uoa03941/databases/humann_db"
export HUMANN_ENV="apptainer exec --cleanenv -B $PWD:/data -B $(realpath $HUMANN_DB_DIR):$(realpath $HUMANN_DB_DIR) docker://$HUMANN_CONTAINER_URL"
#export HUMANN_ENV="docker run --rm -v $PWD:/data -w /data $HUMANN_CONTAINER_URL"
#export HUMANN_ENV=""
export HUMANN_RES="--cpus-per-task=8 --mem=32G --time=12:00:00 --output=$OUTPUT/logs/humann/%x_%j.out"

# Strainphlan
export MIN_SAMPLES_PER_MARKER=2
export MIN_MARKERS_PER_SAMPLE=10

# Activate Python virtual environment
source venv/bin/activate

# Parallel command
module load Parallel
JOBS=4
PARALLEL_CMD() {
  local input="$1"
  local log_name="$2"
  shift 2  # This removes both 'input' and 'log_name' from the argument list
  parallel \
    --header : \
    --colsep $'\t' \
    --joblog "$OUTPUT/logs/${log_name}.log" \
    --resume-failed \
    --jobs "${JOBS:-2}" \
    "$@" \
    :::: "$input"
}
