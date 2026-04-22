#!/usr/bin/env bash
#SBATCH --job-name=sample2markers
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=2:00:00
#SBATCH --output=work/logs/sample2markers/sample2markers_%j.log

. env.sh

$METAPHLAN_CMD \
sample2markers.py \
  --input $OUTPUT/metaphlan_sgb/*/*.sam.bz2 \
  -d $METAPHLAN_DB_DIR/mpa_vJan25_CHOCOPhlAnSGB_202503.pkl \
  --output_dir $OUTPUT/strainphlan/markers \
  --nprocs $SLURM_CPUS_PER_TASK
