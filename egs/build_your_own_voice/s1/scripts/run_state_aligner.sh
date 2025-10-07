#!/bin/bash
################################################################################
#
#   SCRIPT NAME: run_state_aligner.sh
#   VERSION:     1.0
#
#   DESCRIPTION:
#       Performs state-level forced alignment using the HTK Speech Recognition
#       Toolkit (specifically HVite). This script takes audio files (.wav) and
#       text transcriptions as input and produces Merlin-compatible label files
#       with precise timing information for each sub-phonetic HMM state.
#
#       This is a more granular alignment than phone-level alignment and is
#       essential for training the acoustic models in HTS/Merlin.
#
#   DEPENDENCIES:
#       - bash
#       - HTK Speech Recognition Toolkit (HTKDIR must be configured)
#       - A configured environment with paths to:
#         - Festival (FESTDIR)
#         - Merlin (MerlinDir)
#       - Python and required Merlin utility scripts.
#
#   WORKFLOW:
#       1. Generates untimed, full-context linguistic labels from the input
#          text using the Festival front-end.
#       2. Dynamically configures a Python wrapper script with the correct paths
#          for the current project and the HTK binaries.
#       3. Executes the Python script, which calls HTK's HVite tool to perform
#          Viterbi alignment between the audio and the linguistic labels.
#       4. The final output is a directory of state-aligned label files.
#
#   USAGE:
#       ./run_state_aligner.sh <path_to_wav_dir> <path_to_text_dir> \
#                              <path_to_output_labels_dir> <path_to_global_conf>
#
#   EXAMPLE:
#       ./run_state_aligner.sh database/wav database/txt \
#                              database/labels conf/global_settings.cfg
#
################################################################################

source "$(dirname "$0")/../../.env"

if test "$#" -ne 4; then
    echo "Usage: ./run_state_aligner.sh <path_to_wav_dir> <path_to_text_dir> <path_to_labels_dir> <path_to_global_conf_file>"
    exit 1
fi

### Arguments
wav_dir=$1
inp_txt=$2
lab_dir=$3
global_config_file=$4

### Use paths from global config file
source $global_config_file

### force-alignment scripts
aligner=${MerlinDir}/misc/scripts/alignment/state_align

# initializations
train=true

####################################
######## prepare labels ############
####################################

### do prepare full-contextual labels without timestamps
echo "preparing full-contextual labels using Festival frontend..."
bash ${WorkDir}/scripts/prepare_labels_from_txt.sh $inp_txt $lab_dir $global_config_file $train

status_prev_step=$?
if [ $status_prev_step -eq 1 ]; then
    echo "Preparation of full-contextual labels unsuccessful!!"
    echo "Please check scripts/prepare_labels_from_txt.sh"
    exit 1
fi

### tools required
if [[ ! -d "${HTKDIR}" ]]; then
    echo "Please configure path to HTK tools in $global_config_file !!"
    exit 1
fi

### do forced alignment using HVite 
echo "forced-alignment using HTK tools..."

sed -i s#'HTKDIR =.*'#'HTKDIR = "'$HTKDIR'"'# $aligner/forced_alignment.py
sed -i s#'work_dir =.*'#'work_dir = "'$WorkDir/$lab_dir'"'# $aligner/forced_alignment.py
sed -i s#'wav_dir =.*'#'wav_dir = "'$WorkDir/$wav_dir'"'# $aligner/forced_alignment.py

python $aligner/forced_alignment.py

state_labels=$lab_dir/label_state_align

if [ ! "$(ls -A ${state_labels})" ]; then
    echo "Force-alignment unsucessful!! Please check $aligner/forced_alignment.py"
else
    echo "You should have your labels ready in: $state_labels !!"
fi

