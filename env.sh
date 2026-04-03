#!/usr/bin/env bash
set -euo pipefail

# Data path
export INPUT="testdata/*_R{1,2}_001.fastq.gz"
export OUTPUT="work"

# Apptainer
export APPTAINER_CACHEDIR="$PWD/images"

# Configuration
export KNEADDATA_URL="biobakery/kneaddata:latest"
export KNEADDATA_CONTAINER_CMD="apptainer exec -B $PWD:/data -B $(realpath $KNEADDATA_DB_DIR):/kneaddata_db docker://$KNEADDATA_URL"
#export KNEADDATA_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data $KNEADDATA_URL"
export KNEADDATA_DB="human_genome"
export KNEADDATA_DB_DIR="../databases/kneaddata_db"

export METAPHLAN_URL="depot.galaxyproject.org/singularity/metaphlan:4.2.4--pyhdfd78af_0"
export METAPHLAN_CONTAINER_CMD="apptainer exec -B $PWD:/data -B $(realpath $METAPHLAN_DB_DIR):/metaphlan_db docker://$METAPHLAN_URL"
#export METAPHLAN_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data $METAPHLAN_URL"
export METAPHLAN_DB="mpa_vJan25_CHOCOPhlAnSGB_202503"
export METAPHLAN_DB_DIR="../databases/metaphlan_db"

export HUMANN_URL="depot.galaxyproject.org/singularity/humann:3.9--py312hdfd78af_0"
export HUMANN_CONTAINER_CMD="apptainer exec -B $PWD:/data -B $(realpath $HUMANN_DB_DIR):/humann_db docker://$HUMANN_URL"
#export HUMANN_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data $HUMANN_URL"
export HUMANN_DB_DIR="../databases/humann_db"

export BASE_URL="ubuntu"
export BASE_CMD="apptainer exec"

export EXECUTOR="bash"

# Add project paths to PATH
export PATH="code:$PATH"

# Activate Python virtual environment
. venv/bin/activate

module load Parallel

