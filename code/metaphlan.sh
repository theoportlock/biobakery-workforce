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

############################################################
# 1. POSITIONAL ARGUMENT MAPPING (For GNU Parallel/Executor)
# If arguments are passed without flags, map them to variables.
############################################################
# Usage via Parallel: metaphlan.sh <PREFIX> <DB_PATH> <READ1> [READ2]
if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
    PREFIX="$1"; shift
    DB_PATH="$1"; shift
    # Collect remaining as inputs
    INPUTS=("$@")
    # Set a flag to skip the parser below
    SKIP_PARSER=true
fi

############################################################
# CONFIG: Container execution wrapper
############################################################
CONTAINER_CMD="${METAPHLAN_CONTAINER_CMD:-}"

############################################################
# Defaults
############################################################
# Use SLURM_CPUS_PER_TASK if set by the executor, else default to 4
CPUS="${SLURM_CPUS_PER_TASK:-4}"
PREFIX="${PREFIX:-}"
DB_PATH="${DB_PATH:-}"
ARGS="${ARGS:-}"
SAVE_SAM="${SAVE_SAM:-false}"
INPUTS=("${INPUTS[@]:-}")

############################################################
# Usage & Parse arguments (Kept for manual CLI use)
############################################################
usage() {
cat <<EOF
Usage: metaphlan.sh -i <input1> [input2] -d <db_path> -p <prefix> [options]
       OR (Positional): metaphlan.sh <prefix> <db_path> <input1> [input2]
EOF
exit 1
}

if [[ "${SKIP_PARSER:-false}" != "true" ]]; then
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -i|--input) shift; while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do INPUTS+=("$1"); shift; done ;;
        -d|--db) DB_PATH="$2"; shift 2 ;;
        -p|--prefix) PREFIX="$2"; shift 2 ;;
        -t|--threads) CPUS="$2"; shift 2 ;;
        -a|--args) ARGS="$2"; shift 2 ;;
        -s|--save-sam) SAVE_SAM=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown argument: $1"; usage ;;
      esac
    done
fi

# Validation
if [[ ${#INPUTS[@]} -eq 0 || -z "$DB_PATH" || -z "$PREFIX" ]]; then
  echo "ERROR: --input, --db, and --prefix are required"
  usage
fi

############################################################
# IDEMPOTENCY CHECK (For Resuming)
############################################################
if [[ -f "${PREFIX}_profile.txt" ]]; then
    echo "[metaphlan] ${PREFIX} already exists. Skipping."
    exit 0
fi

############################################################
# Logic: Input detection & DB Resolution (Your original code)
############################################################
export TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

INPUT_TYPE=""
INPUT_DATA=""

if [[ "${INPUTS[0]}" =~ \.(fastq|fq|fastq.gz|fq.gz)$ ]]; then
  INPUT_TYPE="--input_type fastq"
  [[ ${#INPUTS[@]} -eq 2 ]] && INPUT_DATA="${INPUTS[0]},${INPUTS[1]}" || INPUT_DATA="${INPUTS[0]}"
elif [[ "${INPUTS[0]}" =~ \.(fasta|fa|fna)$ ]]; then
  INPUT_TYPE="--input_type fasta"; INPUT_DATA="${INPUTS[0]}"
elif [[ "${INPUTS[0]}" =~ bowtie2out\.txt$ ]]; then
  INPUT_TYPE="--input_type bowtie2out"; INPUT_DATA="${INPUTS[0]}"
else
  INPUT_TYPE="--input_type sam"; INPUT_DATA="${INPUTS[0]}"
fi

BT2_DB=$(find -L "${DB_PATH}" -name "*rev.1.bt2*" -exec dirname {} \; | head -n1)
BT2_DB_INDEX=$(find -L "${DB_PATH}" -name "*.rev.1.bt2*" | head -n1 | sed 's/\.rev.1.bt2.*$//' | xargs basename)

BOWTIE2_OUT=""
SAM_OUT=""
[[ ! "$INPUT_TYPE" =~ bowtie2out|sam ]] && BOWTIE2_OUT="--bowtie2out ${PREFIX}.bowtie2out.txt"
[[ "$SAVE_SAM" == true ]] && SAM_OUT="-s ${PREFIX}.sam"

############################################################
# Build & Execute
############################################################
MP_CMD="metaphlan \
  --nproc ${CPUS} \
  ${INPUT_TYPE} \
  ${INPUT_DATA} \
  ${ARGS} \
  ${BOWTIE2_OUT} \
  ${SAM_OUT} \
  --bowtie2db ${BT2_DB} \
  --index ${BT2_DB_INDEX} \
  --biom ${PREFIX}.biom \
  --output_file ${PREFIX}_profile.txt"

echo "[metaphlan] Running ${PREFIX} with ${CPUS} threads"

if [[ -n "$CONTAINER_CMD" ]]; then
  eval "${CONTAINER_CMD} ${MP_CMD}"
else
  eval "${MP_CMD}"
fi

# Versions
if [[ -n "$CONTAINER_CMD" ]]; then
  META_VER=$(${CONTAINER_CMD} metaphlan --version 2>&1 | awk '{print $3}')
else
  META_VER=$(metaphlan --version 2>&1 | awk '{print $3}')
fi

cat <<EOF > "${PREFIX}_versions.yml"
metaphlan:
  version: ${META_VER}
EOF

echo "MetaPhlAn finished successfully."
