#!/bin/bash

# Author: Ryan M
# This script converts paths when testing from default to specific for your machine.
# How-To:
#     $ cd egs/build_your_own_voice/voice_name
#     $ ./convert_paths.sh
#

# --- Configuration ---
SCRIPT_NAME=$(basename "$0")

# --- Source Utility Functions & Check SED ---
SED=sed
source "$(dirname "$0")/config_utils.sh" || error_exit "Failed to source config_utils.sh"
source "$(dirname "$0")/../../.env"

# --- Variables ---
CURRENT_DIR=$(pwd)
echo $CURRENT_DIR
PROJECT_ROOT=$(realpath "${CURRENT_DIR}/../../..")
HTK_BIN_DIR="${PROJECT_ROOT}/tools/bin/htk"
EST_TOOLS="${PROJECT_ROOT}/tools/speech_tools"
FESTIVAL="${PROJECT_ROOT}/tools/festival"
FESTVOX="${PROJECT_ROOT}/tools/festvox"
DATABASE_LAB="${CURRENT_DIR}/database/lab/"
DATABASE_WAV="${CURRENT_DIR}/database/wav/"

# --- Update .conf files ---
file_to_update=$(find "${CURRENT_DIR}/conf" -name "*.conf")
if [[ -n "$file_to_update" ]]; then
    apply_sed_substitutions "${file_to_update}" \
        'Merlin:.*' "Merlin: ${PROJECT_ROOT}" \
        'TOPLEVEL:.*' "TOPLEVEL: ${CURRENT_DIR}" \
        'merlin =.*' "merlin = ${PROJECT_ROOT}" \
        'toplevel =.*' "toplevel = ${CURRENT_DIR}"
else
    echo "Warning: No .conf files found in ${CURRENT_DIR}/conf"
fi

# --- Update .cfg files ---
file_to_update=$(find "${CURRENT_DIR}/conf" -name "*.cfg")
if [[ -n "$file_to_update" ]]; then
    apply_sed_substitutions "${file_to_update}" \
        'MerlinDir=.*' "MerlinDir=${PROJECT_ROOT}" \
        'WorkDir=.*' "WorkDir=${CURRENT_DIR}" \
        'TOPLEVEL=.*' "TOPLEVEL=${CURRENT_DIR}" \
        'ESTDIR=.*' "ESTDIR=${EST_TOOLS}" \
        'FESTDIR=.*' "FESTDIR=${FESTIVAL}" \
        'FESTVOXDIR=.*' "FESTVOXDIR=${FESTVOX}" \
        'HTKDIR=.*' "HTKDIR=${HTK_BIN_DIR}"
else
    echo "Warning: No .cfg files found in ${CURRENT_DIR}/conf"
fi

# --- Update forced_alignment.py ---
file_to_update="${PROJECT_ROOT}/misc/scripts/alignment/state_align/forced_alignment.py"
if [[ -f "$file_to_update" ]]; then
    apply_sed_substitutions "${file_to_update}" \
        'HTKDIR =.*' "HTKDIR = ${HTK_BIN_DIR}" \
        'work_dir =.*' "work_dir = ${DATABASE_LAB}" \
        'wav_dir =.*' "wav_dir = ${DATABASE_WAV}"
else
    echo "Warning: forced_alignment.py not found at ${file_to_update}"
fi

exit 0
