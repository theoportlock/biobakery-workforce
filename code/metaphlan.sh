#!/usr/bin/env bash
#SBATCH --job-name=metaphlan
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=work/logs/metaphlan/metaphlan_%j.log

set -euo pipefail
export LC_ALL=C

# --- 1. Positional Arguments ---
PREFIX="${1:?Missing PREFIX}"
DB_PATH="${2:?Missing DB_PATH}"
READ1="${3:?Missing READ1}"
READ2="${4:-}"
OUTDIR="${5:?Missing OUTDIR}"

# --- 2. Resources & Environment ---
CPUS="${SLURM_CPUS_PER_TASK:-4}"
CONTAINER_CMD="${METAPHLAN_CONTAINER_CMD:-}"

# --- 3. Host-Side Setup ---
SAMPLE_OUT_HOST="${OUTDIR}/${PREFIX}_metaphlan"
EXPECTED_OUT_HOST="${SAMPLE_OUT_HOST}/${PREFIX}_profile.txt"

if [[ -f "${EXPECTED_OUT_HOST}" ]]; then
    echo "[metaphlan] ${PREFIX} already processed. Skipping."
    exit 0
fi

mkdir -p "$SAMPLE_OUT_HOST"

# --- 4. Path Translation (Host -> Container) ---
translate_to_container() {
    local p="$1"
    [[ -z "$p" ]] && return

    local abs_p
    abs_p=$(realpath "$p")

    if [[ -n "$CONTAINER_CMD" ]]; then
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

READ1_CT=$(translate_to_container "$READ1")
READ2_CT=$(translate_to_container "$READ2")
DB_PATH_CT=$(translate_to_container "$DB_PATH")
SAMPLE_OUT_CT=$(translate_to_container "$SAMPLE_OUT_HOST")

# --- 5. Input Detection ---
INPUT_TYPE=""
INPUT_DATA=""

if [[ "${READ1}" =~ \.(fastq|fq|fastq.gz|fq.gz)$ ]]; then
  INPUT_TYPE="--input_type fastq"
  [[ -n "$READ2" ]] && INPUT_DATA="${READ1_CT},${READ2_CT}" || INPUT_DATA="${READ1_CT}"
elif [[ "${READ1}" =~ \.(fasta|fa|fna)$ ]]; then
  INPUT_TYPE="--input_type fasta"; INPUT_DATA="${READ1_CT}"
elif [[ "${READ1}" =~ bowtie2out\.txt$ ]]; then
  INPUT_TYPE="--input_type bowtie2out"; INPUT_DATA="${READ1_CT}"
else
  INPUT_TYPE="--input_type sam"; INPUT_DATA="${READ1_CT}"
fi

BT2_DB=$(find -L "${DB_PATH}" -name "*rev.1.bt2*" -exec dirname {} \; | head -n1)
BT2_DB_INDEX=$(find -L "${DB_PATH}" -name "*.rev.1.bt2*" | head -n1 | sed 's/\.rev.1.bt2.*$//' | xargs basename)

# --- 6. Build Command ---
BOWTIE2_OUT=""
SAM_OUT=""
[[ ! "$INPUT_TYPE" =~ bowtie2out|sam ]] && BOWTIE2_OUT="--bowtie2out ${SAMPLE_OUT_CT}/${PREFIX}.bowtie2out.txt"
[[ "${SAVE_SAM:-false}" == true ]] && SAM_OUT="-s ${SAMPLE_OUT_CT}/${PREFIX}.sam"

CMD=(
    metaphlan
    --nproc "${CPUS}"
    ${INPUT_TYPE}
    ${INPUT_DATA}
    ${ARGS:-}
    ${BOWTIE2_OUT}
    ${SAM_OUT}
    --bowtie2db "${BT2_DB}"
    --index "${BT2_DB_INDEX}"
    --biom "${SAMPLE_OUT_CT}/${PREFIX}.biom"
    --output_file "${SAMPLE_OUT_CT}/${PREFIX}_profile.txt"
)

echo "[metaphlan] Executing for ${PREFIX}..."

if [[ -n "$CONTAINER_CMD" ]]; then
    $CONTAINER_CMD "${CMD[@]}"
else
    "${CMD[@]}"
fi

# --- 7. Record Versions ---
if [[ -n "$CONTAINER_CMD" ]]; then
    META_VER=$($CONTAINER_CMD metaphlan --version 2>&1 | awk '{print $3}')
else
    META_VER=$(metaphlan --version 2>&1 | awk '{print $3}')
fi

cat > "${SAMPLE_OUT_HOST}/versions.yml" <<EOF
metaphlan:
  version: "${META_VER}"
EOF

echo "[metaphlan] DONE ${PREFIX}"