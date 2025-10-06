#!/bin/bash -e

################################################################################
#
#   SCRIPT NAME: run_phone_aligner.sh
#   VERSION:     1.0
#
#   DESCRIPTION:
#       Performs forced alignment to generate time-aligned phonetic labels from
#       audio (.wav) files and their corresponding text transcriptions (.txt).
#       This script automates the entire process by leveraging the FestVox
#       Clustergen toolkit's HMM-based aligner (ehmm).
#
#       The final output is a set of Merlin-compatible, full-context label
#       files that contain accurate timing information for each phoneme, derived
#       directly from the audio.
#
#   DEPENDENCIES:
#       - bash
#       - A configured environment with paths to:
#         - Festival (FESTDIR)
#         - FestVox (FESTVOXDIR)
#         - Edinburgh Speech Tools (ESTDIR)
#       - Python and required Merlin utility scripts.
#
#   WORKFLOW:
#       1. Sets up a temporary FestVox Clustergen voice build environment.
#       2. Copies the user-provided WAV files and text data into the project.
#       3. Runs the Clustergen build process, which performs forced alignment
#          to create time-aligned Festival utterance (.utt) files.
#       4. Calls the 'make_labels' script to convert these timed .utt files
#          into full-context label files.
#       5. Normalizes the labels into the final format required for Merlin.
#
#   USAGE:
#       ./run_phone_aligner.sh <path_to_wav_dir> <path_to_text_dir> \
#                              <path_to_output_labels_dir> <path_to_global_conf>
#
#   EXAMPLE:
#       ./run_phone_aligner.sh database/wav database/txt \
#                              database/labels conf/global_settings.cfg
#
################################################################################

source "$(dirname "$0")/../../.env"

if test "$#" -ne 4; then
    echo "Usage: ./run_phone_aligner.sh <path_to_wav_dir> <path_to_text_dir> <path_to_labels_dir> <path_to_global_conf_file>"
    exit 1
fi

### Arguments
wav_dir=$1
inp_txt=$2
lab_dir=$3
global_config_file=$4

### Use paths from global config file
source $global_config_file

### frontend scripts
frontend=${MerlinDir}/misc/scripts/frontend

#################################################################
##### Create training labels for merlin with festvox tools ######
#################################################################

### tools required

if [[ ! -d "${ESTDIR}" ]] || [[ ! -d "${FESTDIR}" ]] || [[ ! -d "${FESTVOXDIR}" ]]; then
    echo "Please configure paths to speech_tools, festival and festvox in config.cfg !!"
    exit 1
fi

### do forced alignment using ehmm in clustergen setup
mkdir -p $lab_dir
cd $lab_dir
mkdir cmu_us_${Voice}
cd cmu_us_${Voice}

$FESTVOXDIR/src/clustergen/setup_cg cmu us ${Voice} 

txt_file=${WorkDir}/${inp_txt}
txt_dir=${WorkDir}/${inp_txt}

if [ -f "${txt_file}" ]; then
    cp ${txt_file} etc/txt.done.data
elif [ -d "${txt_dir}" ]; then
    python ${frontend}/utils/prepare_txt_done_data_file.py ${txt_dir} etc/txt.done.data
else
    echo "Please check ${inp_txt} !!"
    exit 1
fi

cp $WorkDir/$wav_dir/*.wav wav/

./bin/do_build build_prompts 
./bin/do_build label
./bin/do_build build_utts

cd ../

### convert festival utts to lab

cat cmu_us_${Voice}/etc/txt.done.data | cut -d " " -f 2 > file_id_list.scp

echo "converting festival utts to labels..."
${frontend}/festival_utt_to_lab/make_labels \
                        full-context-labels \
                        cmu_us_${Voice}/festival/utts \
                        ${FESTDIR}/examples/dumpfeats \
                        ${frontend}/festival_utt_to_lab 

echo "normalizing label files for merlin..."
python ${frontend}/utils/normalize_lab_for_merlin.py \
                        full-context-labels/full \
                        label_phone_align \
                        phone_align \
                        file_id_list.scp

### return to working directory
cd ${WorkDir}

phone_labels=$lab_dir/label_phone_align

if [ ! "$(ls -A ${phone_labels})" ]; then
    echo "Force-alignment unsucessful!!"
else
    echo "You should have your labels ready in: $phone_labels !!"
fi


