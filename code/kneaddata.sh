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

# --- Argument Mapping ---
PREFIX="${1:?Missing PREFIX}"
READ1="${2:?Missing READ1}"
READ2="${3:-}"
REF_DB="${4:?Missing REF_DB}"
OUTDIR="${5:?Missing OUTDIR}"

# --- Resources ---
CPUS="${SLURM_CPUS_PER_TASK:-4}"
TRIMMOMATIC_PATH="${TRIMMOMATIC_PATH:-/usr/share/java/trimmomatic.jar}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
CONTAINER_CMD="${KNEADDATA_CONTAINER_CMD:-}"

# --- Path translation (HOST -> CONTAINER) ---
translate_path() {
  local p="$1"

  # Make absolute if relative
  if [[ "$p" != /* ]]; then
    p="$(realpath "$p")"
  fi

  # Only translate if using container
  if [[ -n "$CONTAINER_CMD" ]]; then
    # Ensure path is under project root
    if [[ "$p" == "$PWD"* ]]; then
      echo "/data${p#$PWD}"
    else
      echo "ERROR: Path not under project root: $p" >&2
      exit 1
    fi
  else
    echo "$p"
  fi
}

READ1=$(translate_path "$READ1")
[[ -n "$READ2" ]] && READ2=$(translate_path "$READ2")
REF_DB=$(translate_path "$REF_DB")
OUTDIR=$(translate_path "$OUTDIR")

# --- Validate inputs (host-side before translation ideally, but still useful) ---
[[ -n "$READ1" ]] || { echo "ERROR: READ1 empty"; exit 1; }
[[ -n "$REF_DB" ]] || { echo "ERROR: REF_DB empty"; exit 1; }

# --- Output structure ---
SAMPLE_OUT="${OUTDIR}/${PREFIX}_kneaddata"
EXPECTED_OUT="${SAMPLE_OUT}/${PREFIX}_kneaddata_paired_1.fastq"

# --- Resume safety ---
if [[ -f "${EXPECTED_OUT}" ]]; then
    echo "[kneaddata] ${PREFIX} already processed. Skipping."
    exit 0
fi

mkdir -p "$SAMPLE_OUT"

# --- Build command ---
CMD=(
  kneaddata
  --input "${READ1}"
  --threads "${CPUS}"
  --reference-db "${REF_DB}"
  --output "${SAMPLE_OUT}"
  --output-prefix "${PREFIX}"
)

if [[ -n "$READ2" ]]; then
  CMD+=(--input "${READ2}")
fi

if [[ -n "${EXTRA_ARGS}" ]]; then
  # shellcheck disable=SC2206
  EXTRA_ARR=(${EXTRA_ARGS})
  CMD+=("${EXTRA_ARR[@]}")
fi

# --- Debug ---
echo "[kneaddata] PREFIX=${PREFIX}"
echo "[kneaddata] READ1=${READ1}"
echo "[kneaddata] READ2=${READ2:-NA}"
echo "[kneaddata] OUTDIR=${OUTDIR}"
printf '[kneaddata] CMD: %q ' "${CMD[@]}"
echo

# --- Execute ---
if [[ -n "$CONTAINER_CMD" ]]; then
  # shellcheck disable=SC2086
  $CONTAINER_CMD "${CMD[@]}"
else
  "${CMD[@]}"
fi

# --- Version ---
if [[ -n "$CONTAINER_CMD" ]]; then
  VER=$($CONTAINER_CMD kneaddata --version 2>&1 | head -n1)
else
  VER=$(kneaddata --version 2>&1 | head -n1)
fi

cat > "${SAMPLE_OUT}/versions.yml" <<EOF
kneaddata:
  version: "${VER}"
EOF

echo "[kneaddata] DONE ${PREFIX}"
