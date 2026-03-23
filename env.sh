#!/usr/bin/env bash
# Environment setup for fellowship project

# Data path
export INPUT="testdata/*_R{1,2}_001.fastq.gz"
export OUTPUT="work"

# TESTING
#export read1="testdata/FG00004_S26_L001_R1_001.fastq.gz"
#export read2="testdata/FG00004_S26_L002_R2_001.fastq.gz"

# Configuration
export KNEADDATA_DB="human_genome"
export KNEADDATA_DB_DIR="db/kneaddata_db"
#export KNEADDATA_CONTAINER_CMD="docker run --rm -v ${PWD}:${PWD} -v $PWD:/data -w /data biobakery/kneaddata:latest"
export KNEADDATA_CONTAINER_CMD="docker run --rm -v $PWD:/data -w /data biobakery/kneaddata:latest"
#export KNEADDATA_CONTAINER_CMD="singularity exec --bind /path/to/data:/data kneaddata.sif"

#export EXECUTOR="sbatch --wait"
export EXECUTOR="bash"

# Add project paths to PATH
export PATH="code:$PATH"

# Activate Python virtual environment
if [ -f venv/bin/activate ]; then
    . venv/bin/activate
else
    echo "No venv found at venv/bin/activate"
fi

