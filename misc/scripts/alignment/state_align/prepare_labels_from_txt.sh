#!/bin/bash
################################################################################
#
#   SCRIPT NAME: prepare_labels_from_txt.sh
#   VERSION:     1.0
#
#   DESCRIPTION:
#       Automates the generation of untimed, full-context linguistic labels
#       from a directory of text files or a single multi-sentence text file.
#       This script orchestrates the entire Festival front-end pipeline to
#       produce the linguistic features required for a subsequent forced
#       alignment stage.
#
#       The final output is a directory of label files (`label_no_align`) that
#       contain rich linguistic context but no timing information.
#
#   DEPENDENCIES:
#       - bash
#       - A configured environment with paths to Festival (FESTDIR) and the
#         Merlin scripts (frontend).
#       - Python and required Merlin utility scripts.
#
#   WORKFLOW:
#       1. Reads text input from either a directory of .txt files or a single
#          formatted .data file.
#       2. Generates a Festival Scheme script (`.scm`) from the text input.
#       3. Executes Festival in batch mode to process the scheme script,
#          creating utterance files (`.utt`).
#       4. Calls the 'make_labels' script to convert the .utt files into
#          full-context labels.
#       5. Normalizes the labels into the final format required by Merlin,
#          saving them to the 'label_no_align' directory.
#
#   CONFIGURATION:
#       This script requires a single argument: the path to a configuration
#       file (e.g., config.cfg). All necessary paths (WorkDir, FESTDIR, etc.)
#       are sourced from this file.
#
#   USAGE:
#       ./prepare_labels_from_txt.sh <path_to_config_file>
#
#   EXAMPLE:
#       ./prepare_labels_from_txt.sh conf/global_settings.cfg
#
################################################################################

if test "$#" -ne 1; then
    echo "Usage: ./prepare_labels_from_txt.sh config.cfg"
    exit 1
fi

if [ ! -f $1 ]; then
    echo "Config file doesn't exist"
    exit 1
else
    source $1
fi

### tools required
if [ ! -d "${FESTDIR}" ]; then
    echo "Please configure festival path in config.cfg !!"
    exit 1
fi

txt_dir=${WorkDir}/txt
txt_file=${WorkDir}/cmuarctic.data

### create a scheme file with options from: txt directory or utts.data file

if [ -d "${txt_dir}" ]; then
    if [ ! "$(ls -A ${txt_dir})" ]; then
        echo "Please place your new test sentences (files) in: ${txt_dir} !!"
        exit 1
    else
        in_txt=${txt_dir}
    fi
elif [ -f "${txt_file}" ]; then
    in_txt=${txt_file}
else
    echo "Please give input: either 1 or 2"
    echo "1. ${txt_dir}  -- a text directory containing text files"
    echo "2. ${txt_file} -- a single text file with each sentence in a new line in festival format"
    exit 1
fi

python ${frontend}/utils/genScmFile.py \
                            ${in_txt} \
                            ${WorkDir}/prompt-utt \
                            ${WorkDir}/cmuarctic.scm \
                            ${WorkDir}/file_id_list.scp 

### generate utt from scheme file
echo "generating utts from scheme file"
${FESTDIR}/bin/festival -b ${WorkDir}/cmuarctic.scm 

### convert festival utt to lab
echo "converting festival utts to labels..."
${frontend}/festival_utt_to_lab/make_labels \
                            ${WorkDir}/prompt-lab \
                            ${WorkDir}/prompt-utt \
                            ${FESTDIR}/examples/dumpfeats \
                            ${frontend}/festival_utt_to_lab

### normalize lab for merlin with options: state_align or phone_align
echo "normalizing label files for merlin..."
python ${frontend}/utils/normalize_lab_for_merlin.py \
                            ${WorkDir}/prompt-lab/full \
                            ${WorkDir}/label_no_align \
                            phone_align \
                            ${WorkDir}/file_id_list.scp 0

echo "Labels are ready in: ${WorkDir}/label_no_align !!"
