#!/usr/bin/env bash
#SBATCH --job-name=metaphlan
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=1:00:00
#SBATCH --output=work/logs/metaphlan/metaphlan_%j.log

set -euo pipefail
export LC_ALL=C

# --- 1. Argument Mapping (Host Paths) ---
PREFIX="${1:?Missing PREFIX}"
READ1_HOST=$(realpath "${2:?Missing READ1}")
READ2_HOST=""
[[ -n "${3:-}" ]] && READ2_HOST=$(realpath "$3")
DB_PATH_HOST=$(realpath "${4:?Missing DB_PATH}")
OUTDIR_HOST=$(realpath "${5:?Missing OUTDIR}")

# --- 2. Resources ---
CPUS="${SLURM_CPUS_PER_TASK:-4}"

# --- 3. Host-Side Setup ---
SAMPLE_OUT_HOST="${OUTDIR_HOST}/${PREFIX}_metaphlan"
EXPECTED_OUT_HOST="${SAMPLE_OUT_HOST}/${PREFIX}_profile.txt"

if [[ -f "${EXPECTED_OUT_HOST}" ]]; then
    echo "[metaphlan] ${PREFIX} already processed. Skipping."
    exit 0
fi

mkdir -p "$SAMPLE_OUT_HOST"

# --- 4. Dynamic Mounting (identity mapping) ---
MOUNTS=$(printf "%s\n" \
    "$(dirname "$READ1_HOST")" \
    "$(dirname "$READ2_HOST")" \
    "$DB_PATH_HOST" \
    "$OUTDIR_HOST" | sort -u | sed 's/^/-B /' | tr '\n' ' ')

# --- 5. Input Detection ---
INPUT_TYPE=""
INPUT_DATA=""

if [[ "${READ1_HOST}" =~ \.(fastq|fq|fastq.gz|fq.gz)$ ]]; then
    INPUT_TYPE="--input_type fastq"
    [[ -n "$READ2_HOST" ]] && INPUT_DATA="${READ1_HOST},${READ2_HOST}" || INPUT_DATA="${READ1_HOST}"
elif [[ "${READ1_HOST}" =~ \.(fasta|fa|fna)$ ]]; then
    INPUT_TYPE="--input_type fasta"
    INPUT_DATA="${READ1_HOST}"
elif [[ "${READ1_HOST}" =~ bowtie2out\.txt$ ]]; then
    INPUT_TYPE="--input_type bowtie2out"
    INPUT_DATA="${READ1_HOST}"
else
    INPUT_TYPE="--input_type sam"
    INPUT_DATA="${READ1_HOST}"
fi

# --- 6. Detect MetaPhlAn DB ---
BT2_DB=$(find -L "${DB_PATH_HOST}" -name "*rev.1.bt2*" -exec dirname {} \; | head -n1)
BT2_DB_INDEX=$(find -L "${DB_PATH_HOST}" -name "*.rev.1.bt2*" | head -n1 | sed 's/\.rev.1.bt2.*$//' | xargs basename)

# --- 7. Other Outputs ---
BOWTIE2_OUT=("--mapout" "${SAMPLE_OUT_HOST}/${PREFIX}.bowtie2out.txt")
SAM_OUT=("-s" "${SAMPLE_OUT_HOST}/${PREFIX}.sam.bz2")

# --- 8. Build Command (same ordering style as kneaddata) ---
CMD=(
    metaphlan
    "${INPUT_DATA}"
    ${INPUT_TYPE}
    --nproc "${CPUS}"
    --db_dir "${BT2_DB}"
    --index "${BT2_DB_INDEX}"
    -o "${SAMPLE_OUT_HOST}/${PREFIX}_profile.txt"
    --biom_format_output
    --biom_mdelim "|"
    --force
    "${BOWTIE2_OUT[@]}"
    "${SAM_OUT[@]}"
)

echo "[metaphlan] Executing for ${PREFIX} using identity mounts..."

# --- 9. Execute ---
if [[ -n "${METAPHLAN_CONTAINER_CMD:-}" ]]; then
    # Example:
    # apptainer exec -B ... docker://image metaphlan ...
    $METAPHLAN_CONTAINER_CMD --cleanenv $MOUNTS $METAPHLAN_IMAGE "${CMD[@]}"
else
    "${CMD[@]}"
fi

echo "[metaphlan] DONE ${PREFIX}"

