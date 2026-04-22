#!/usr/bin/env bash
#SBATCH --job-name=kneaddata
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=work/logs/kneaddata/kneaddata_%j.log

set -euo pipefail

# --- 1. Argument Mapping (Capture Host Paths) ---
PREFIX="${1:?Missing PREFIX}"
READ1_HOST=$(realpath "${2:?Missing READ1}")
READ2_HOST=""
[[ -n "${3:-}" ]] && READ2_HOST=$(realpath "$3")
REF_DB_HOST=$(realpath "${4:?Missing REF_DB}")
OUTDIR_HOST=$(realpath "${5:?Missing OUTDIR}")

# --- 2. Resources ---
CPUS="${SLURM_CPUS_PER_TASK:-4}"

# --- 3. Host-Side Setup ---
SAMPLE_OUT_HOST="${OUTDIR_HOST}/${PREFIX}_kneaddata"
mkdir -p "$SAMPLE_OUT_HOST"

# --- 4. Dynamic Mounting Logic ---
# We mount the parent directories of our inputs and the output directory itself.
# Using 'Identity Mapping': host path == container path.
MOUNTS="-B $(dirname "$READ1_HOST") -B $REF_DB_HOST -B $OUTDIR_HOST"
[[ -n "$READ2_HOST" ]] && MOUNTS+=" -B $(dirname "$READ2_HOST")"

# --- 5. Build & Execute Command ---
# Note: We use the host paths directly because they are identical in the container
CMD=(
    kneaddata
    --input "${READ1_HOST}"
    --threads "${CPUS}"
    --reference-db "${REF_DB_HOST}"
    --output "${SAMPLE_OUT_HOST}"
    --output-prefix "${PREFIX}"
)

[[ -n "$READ2_HOST" ]] && CMD+=(--input "${READ2_HOST}")

echo "[kneaddata] Executing for ${PREFIX} using identity mounts..."

if [[ -n "${KNEADDATA_CONTAINER_CMD:-}" ]]; then
    # Runs: apptainer exec -B /path1 -B /path2 docker://img kneaddata ...
    $KNEADDATA_CONTAINER_CMD $MOUNTS $KNEADDATA_IMAGE "${CMD[@]}"
else
    "${CMD[@]}"
fi

echo "[kneaddata] DONE ${PREFIX}"

