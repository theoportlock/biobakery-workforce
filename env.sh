#!/usr/bin/env bash

# Data path
export INPUT="/nesi/nobackup/uoa03941/biobakery-workforce/testdata/*_R{1,2}_001.fastq.gz"
export OUTPUT="work"

# Apptainer
export APPTAINER_CACHEDIR="$PWD/images"
export APPTAINER_TMPDIR="$PWD/images_tmpdir"
# Ensure these directories actually exist
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

# Kneaddata
export KNEADDATA_URL="biobakery/kneaddata:latest"
export KNEADDATA_DB_DIR="/nesi/nobackup/uoa03941/databases/kneaddata_db"
export KNEADDATA_CONTAINER_CMD="apptainer exec"
export KNEADDATA_IMAGE="docker://$KNEADDATA_URL"
#export KNEADDATA_CONTAINER_CMD="apptainer exec -B $PWD:/data -B $(realpath $KNEADDATA_DB_DIR):/kneaddata_db docker://$KNEADDATA_URL"
#export KNEADDATA_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data $KNEADDATA_URL"
export KNEADDATA_DB="human_genome"

# Metaphlan
#export METAPHLAN_URL="depot.galaxyproject.org/singularity/metaphlan:4.2.4--pyhdfd78af_0"
export METAPHLAN_URL="quay.io/biocontainers/metaphlan:4.2.4--pyhdfd78af_0"
export METAPHLAN_DB_DIR="/nesi/nobackup/uoa03941/databases/metaphlan_db"
export METAPHLAN_CONTAINER_CMD="apptainer exec"
export METAPHLAN_IMAGE="docker://$METAPHLAN_URL"
#export METAPHLAN_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data $METAPHLAN_URL"
export METAPHLAN_DB="mpa_vJan25_CHOCOPhlAnSGB_202503"
export METAPHLAN_CMD="$METAPHLAN_CONTAINER_CMD --cleanenv $METAPHLAN_IMAGE"

# Humann
export HUMANN_URL="depot.galaxyproject.org/singularity/humann:3.9--py312hdfd78af_0"
export HUMANN_DB_DIR="/nesi/nobackup/uoa03941/databases/humann_db"
export HUMANN_CONTAINER_CMD="apptainer exec"
#export HUMANN_CONTAINER_CMD="apptainer exec -B $PWD:/data -B $(realpath $HUMANN_DB_DIR):/humann_db docker://$HUMANN_URL"
#export HUMANN_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data $HUMANN_URL"

# Strainphlan
export MIN_SAMPLES_PER_MARKER=2
export MIN_MARKERS_PER_SAMPLE=10


export BASE_URL="ubuntu"
export BASE_CMD="apptainer exec"

#export EXECUTOR="bash"
export EXECUTOR="sbatch --account uoa03941 --wait"

# Add project paths to PATH
export PATH="code:$PATH"

# Activate Python virtual environment
source venv/bin/activate

module load Parallel

