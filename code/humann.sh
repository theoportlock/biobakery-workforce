#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

############################################################
# Container execution wrapper
#   export HUMANN_CONTAINER_CMD="singularity exec humann.sif"
#   export HUMANN_CONTAINER_CMD="docker run --rm -v $PWD:$PWD -w $PWD biobakery/humann:latest"
############################################################
CONTAINER_CMD="${HUMANN_CONTAINER_CMD:-}"

############################################################
# Defaults
############################################################
CPUS=4
PREFIX=""
READS=""
PROFILE=""
HUMANN_DB=""
METAPHLAN_OPTS=""
OUTDIR="."
EXTRA_ARGS=""

############################################################
# Usage
############################################################
usage() {
cat <<EOF
Usage:
  humann.sh -i <reads> -p <tax_profile> -d <humann_db> -s <sample> [options]

Required:
  -i, --input           Input reads (FASTQ/FASTA)
  -p, --profile          MetaPhlAn taxonomic profile
  -d, --db               HUMAnN database root (contains chocophlan/ and uniref/)
  -s, --sample            Output basename (REQUIRED in Workforce)

Optional:
  -t, --threads           Threads (default: 4)
  -o, --outdir             Output directory (default: .)
  -m, --metaphlan-opts     MetaPhlAn options string
  -a, --args                Extra HUMAnN args (quoted)
  -h, --help                Show help

Container:
  export HUMANN_CONTAINER_CMD="singularity exec humann.sif"
  export HUMANN_CONTAINER_CMD="docker run --rm -v \$PWD:\$PWD -w \$PWD biobakery/humann:latest"

Example:
  humann.sh -i S01.fq.gz -p S01_profile.txt -d /db/humann -s S01 -t 32
EOF
exit 1
}

############################################################
# Parse arguments
############################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input) READS="$2"; shift 2 ;;
    -p|--profile) PROFILE="$2"; shift 2 ;;
    -d|--db) HUMANN_DB="$2"; shift 2 ;;
    -s|--sample) PREFIX="$2"; shift 2 ;;
    -t|--threads) CPUS="$2"; shift 2 ;;
    -o|--outdir) OUTDIR="$2"; shift 2 ;;
    -m|--metaphlan-opts) METAPHLAN_OPTS="$2"; shift 2 ;;
    -a|--args) EXTRA_ARGS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

############################################################
# Validation
############################################################
if [[ -z "$READS" || -z "$PROFILE" || -z "$HUMANN_DB" || -z "$PREFIX" ]]; then
  echo "ERROR: --input, --profile, --db, and --sample are required"
  usage
fi

############################################################
# Parallel-safe temp directory
############################################################
export TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

############################################################
# Build HUMAnN command
############################################################
HU_CMD="humann \
  --input ${READS} \
  --taxonomic-profile ${PROFILE} \
  --threads ${CPUS} \
  --remove-temp-output \
  --nucleotide-database ${HUMANN_DB}/chocophlan \
  --protein-database ${HUMANN_DB}/uniref \
  --output-basename ${PREFIX} \
  --output ${OUTDIR} \
  ${EXTRA_ARGS}"

if [[ -n "$METAPHLAN_OPTS" ]]; then
  HU_CMD="${HU_CMD} --metaphlan-options \"${METAPHLAN_OPTS}\""
fi

############################################################
# Execute
############################################################
echo "-------------------------------------------------"
echo "HUMAnN execution"
echo "Sample:       ${PREFIX}"
echo "Threads:      ${CPUS}"
echo "Reads:        ${READS}"
echo "Profile:      ${PROFILE}"
echo "DB root:       ${HUMANN_DB}"
echo "Outdir:        ${OUTDIR}"
echo "Container:     ${CONTAINER_CMD:-native}"
echo "-------------------------------------------------"

mkdir -p "${OUTDIR}"

if [[ -n "$CONTAINER_CMD" ]]; then
  eval "${CONTAINER_CMD} ${HU_CMD}"
else
  eval "${HU_CMD}"
fi

############################################################
# Versions file
############################################################
if [[ -n "$CONTAINER_CMD" ]]; then
  HU_VER=$(${CONTAINER_CMD} humann --version 2>&1 | head -n1)
else
  HU_VER=$(humann --version 2>&1 | head -n1)
fi

cat <<EOF > ${OUTDIR}/${PREFIX}_versions.yml
humann:
  version: "${HU_VER}"
EOF

echo "HUMAnN finished successfully."

