#!/usr/bin/env bash
#SBATCH --job-name=kneaddata
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=work/logs/kneaddata/kneaddata_%j.log

set -euo pipefail
export LC_ALL=C

# --- 1. Argument Mapping (Host Paths) ---
PREFIX="${1:?Missing PREFIX}"
READ1_HOST="${2:?Missing READ1}"
READ2_HOST="${3:-}"
REF_DB_HOST="${4:?Missing REF_DB}"
OUTDIR_HOST="${5:?Missing OUTDIR}"

# --- 2. Resources & Environment ---
CPUS="${SLURM_CPUS_PER_TASK:-4}"
CONTAINER_CMD="${KNEADDATA_CONTAINER_CMD:-}" # e.g., "singularity exec -B .:/data img.sif"

# --- 3. Host-Side Setup ---
# We do this BEFORE path translation so the host actually creates the folders.
SAMPLE_OUT_HOST="${OUTDIR_HOST}/${PREFIX}_kneaddata"
EXPECTED_OUT_HOST="${SAMPLE_OUT_HOST}/${PREFIX}_kneaddata_paired_1.fastq"

if [[ -f "${EXPECTED_OUT_HOST}" ]]; then
    echo "[kneaddata] ${PREFIX} already processed. Skipping."
    exit 0
fi

mkdir -p "$SAMPLE_OUT_HOST"

# --- 4. Path Translation (Host -> Container) ---
# This helper assumes the project root is mounted to /data in the container.
translate_to_container() {
    local p="$1"
    [[ -z "$p" ]] && return

    # Get absolute host path
    local abs_p
    abs_p=$(realpath "$p")

    if [[ -n "$CONTAINER_CMD" ]]; then
        # If the path is inside our current working directory,
        # swap the host prefix for /data
        if [[ "$abs_p" == "$PWD"* ]]; then
            echo "/data${abs_p#$PWD}"
        else
            echo "ERROR: Path $abs_p is outside project root $PWD" >&2
            exit 1
        fi
    else
        echo "$abs_p"
    fi
}

READ1=$(translate_to_container "$READ1_HOST")
READ2=$(translate_to_container "$READ2_HOST")
REF_DB=$(translate_to_container "$REF_DB_HOST")
SAMPLE_OUT=$(translate_to_container "$SAMPLE_OUT_HOST")

# --- 5. Build & Execute Command ---
CMD=(
    kneaddata
    --input "${READ1}"
    --threads "${CPUS}"
    --reference-db "${REF_DB}"
    --output "${SAMPLE_OUT}"
    --output-prefix "${PREFIX}"
)

[[ -n "$READ2" ]] && CMD+=(--input "${READ2}")

# Add any extra args from environment if they exist
if [[ -n "${EXTRA_ARGS:-}" ]]; then
    read -r -a EXTRA_ARR <<< "${EXTRA_ARGS}"
    CMD+=("${EXTRA_ARR[@]}")
fi

echo "[kneaddata] Executing for ${PREFIX}..."
if [[ -n "$CONTAINER_CMD" ]]; then
    $CONTAINER_CMD "${CMD[@]}"
else
    "${CMD[@]}"
fi

# --- 6. Record Versions ---
VER_CMD="kneaddata --version"
if [[ -n "$CONTAINER_CMD" ]]; then
    VER=$($CONTAINER_CMD $VER_CMD 2>&1 | head -n1)
else
    VER=$($VER_CMD 2>&1 | head -n1)
fi

cat > "${SAMPLE_OUT_HOST}/versions.yml" <<EOF
kneaddata:
  version: "${VER}"
EOF

echo "[kneaddata] DONE ${PREFIX}"
