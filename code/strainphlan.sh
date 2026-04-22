#!/usr/bin/env bash
#SBATCH --job-name=strainphlan
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=2:00:00
#SBATCH --output=work/logs/strainphlan/strainphlan_%j.log

set -euo pipefail
source env.sh

# --- 1. Argument Mapping ---
SGB="${1:?Missing SGB clade}"
MARKERS_DIR="${2:?Missing markers dir}"
OUTDIR="${3:?Missing output dir}"

# --- 2. Resources ---
CPUS="${SLURM_CPUS_PER_TASK:-$CPUS}"

# --- 3. Optional reference genome ---
REF_OPT=()
[[ -n "${4:-}" ]] && REF_OPT=("--reference_genomes" "$4")

# --- 4. Skip if already done ---
EXPECTED="${OUTDIR}/${SGB}"
if [[ -d "$EXPECTED" ]]; then
    echo "[strainphlan] ${SGB} already processed. Skipping."
    exit 0
fi

mkdir -p "$OUTDIR"

# --- 5. Execute ---
echo "[strainphlan] Running for clade ${SGB}..."

$METAPHLAN_CMD \
strainphlan \
  --samples ${MARKERS_DIR}/*.pkl \
  --output_dir "$OUTDIR" \
  --clades "$SGB" \
  --nprocs "$CPUS" \
  --marker_in_n_samples "${MIN_SAMPLES_PER_MARKER:-2}" \
  --sample_with_n_markers "${MIN_MARKERS_PER_SAMPLE:-10}" \
  --phylophlan_mode accurate \
  --mutation_rates \
  "${REF_OPT[@]}"

mv "${OUTDIR}/${SGB}" .

echo "[strainphlan] DONE ${SGB}"
