#!/usr/bin/env bash
set -e

# Data path
export INPUT="testdata/*_R{1,2}_001.fastq.gz"
export OUTPUT="work"

# Configuration
export KNEADDATA_DB="human_genome"
export KNEADDATA_DB_DIR="db/kneaddata_db"
export KNEADDATA_CONTAINER_CMD="singularity exec -B $PWD:/data images/kneaddata.sif"
#export KNEADDATA_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data biobakery/kneaddata:latest"

export METAPHLAN_DB="mpa_vJan25_CHOCOPhlAnSGB_202503"
export METAPHLAN_DB_DIR="db/metaphlan_db"
export METAPHLAN_CONTAINER_CMD="singularity exec -B $PWD:/data images/metaphlan.sif"
#export METAPHLAN_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data biobakery/metaphlan:latest"

export EXECUTOR="bash"
#export EXECUTOR="sbatch --wait"

# Add project paths to PATH
export PATH="code:$PATH"

# Activate Python virtual environment
. venv/bin/activate
