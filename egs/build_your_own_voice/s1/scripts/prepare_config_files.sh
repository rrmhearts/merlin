#!/bin/bash

# --- Configuration ---
GLOBAL_CONFIG="$1"
SCRIPT_NAME=$(basename "$0") # Get the script's name for error messages

# --- Source Utility Functions & SED check ---
SED=sed
source "$(dirname "$0")/config_utils.sh" || error_exit "Failed to source config_utils.sh"
 

# --- Argument Validation ---

if [[ $# -ne 1 ]]; then
  echo "Usage: ./${SCRIPT_NAME} conf/global_settings.cfg"
  exit 1
fi

if [[ ! -f "${GLOBAL_CONFIG}" ]]; then
  error_exit "Global config file '${GLOBAL_CONFIG}' does not exist."
fi

# --- Load Global Configuration ---
source "$(dirname "$0")/../../.env"
source "${GLOBAL_CONFIG}" || error_exit "Failed to source global config file."

# --- SED Check ---
SED=sed
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v gsed &> /dev/null; then
    error_exit "GNU sed (gsed) is required on macOS.  Install it with 'brew install gnu-sed'."
  fi
  SED=gsed
fi

# --- Configuration File Generation ---

# --- Duration Configuration ---
duration_config_file="conf/duration_${Voice}.conf"
duration_demo_config="$WorkDir/conf/general/duration_demo.conf"
duration_merlin_config="$MerlinDir/misc/recipes/duration_demo.conf"

# Copy base configuration
if [[ -f "${duration_demo_config}" ]]; then
  cp -f "${duration_demo_config}" "${duration_config_file}"
else
  cp -f "${duration_merlin_config}" "${duration_config_file}"
fi

# Apply duration-specific substitutions
apply_sed_substitutions "${duration_config_file}" \
  'Merlin:.*' "Merlin: ${MerlinDir}" \
  'TOPLEVEL:.*' "TOPLEVEL: ${WorkDir}" \
  'work:.*' "work: %(TOPLEVEL)s/experiments/${Voice}/duration_model" \
  'file_id_list:.*' "file_id_list: %(data)s/${FileIDList}" \
  "silence_pattern:.*" "silence_pattern: ['*-${SilencePhone}+*']" \
  'label_type:.*' "label_type: ${Labels}" \
  'label_align:.*' "label_align: %(TOPLEVEL)s/experiments/${Voice}/duration_model/data/label_${Labels}" \
  'question_file_name:.*' "question_file_name: %(Merlin)s/misc/questions/${QuestionFile}"

# Output-specific duration settings
case "${Labels}" in
  state_align)
    ${SED} -i 's#dur\s*:.*#dur: 5#' "${duration_config_file}"
    ;;
  phone_align)
    ${SED} -i 's#dur\s*:.*#dur: 1#' "${duration_config_file}"
    ;;
  *)
    echo "ERROR: These labels (${Labels}) are not supported. Use state_align or phone_align!!" >&2
    exit 1
    ;;
esac

# Architecture-specific duration settings
if [[ "${Voice}" == *"demo"* ]]; then
  ${SED} -i 's#hidden_layer_size\s*:.*#hidden_layer_size: [512, 512, 512, 512]#' "${duration_config_file}"
  ${SED} -i "s#hidden_layer_type\s*:.*#hidden_layer_type: [''TANH'', ''TANH'', ''TANH'', ''TANH'']#" "${duration_config_file}"
fi

# Data-specific duration settings
apply_sed_substitutions "${duration_config_file}" \
  'train_file_number\s*:.*' "train_file_number: ${Train}" \
  'valid_file_number\s*:.*' "valid_file_number: ${Valid}" \
  'test_file_number\s*:.*' "test_file_number: ${Test}"

echo "Duration configuration settings stored in ${duration_config_file}"

# --- Acoustic Configuration ---
acoustic_config_file="conf/acoustic_${Voice}.conf"
acoustic_demo_config="$WorkDir/conf/general/acoustic_demo.conf"
acoustic_merlin_config="$MerlinDir/misc/recipes/acoustic_demo.conf"

# Copy base configuration
if [[ -f "${acoustic_demo_config}" ]]; then
  cp -f "${acoustic_demo_config}" "${acoustic_config_file}"
else
  cp -f "${acoustic_merlin_config}" "${acoustic_config_file}"
fi

# Apply acoustic-specific substitutions
apply_sed_substitutions "${acoustic_config_file}" \
  'Merlin:.*' "Merlin: ${MerlinDir}" \
  'TOPLEVEL:.*' "TOPLEVEL: ${WorkDir}" \
  'work:.*' "work: %(TOPLEVEL)s/experiments/${Voice}/acoustic_model" \
  'file_id_list:.*' "file_id_list: %(data)s/${FileIDList}" \
  "silence_pattern:.*" "silence_pattern: ['*-${SilencePhone}+*']" \
  'label_type:.*' "label_type: ${Labels}" \
  'label_align:.*' "label_align: %(TOPLEVEL)s/experiments/${Voice}/acoustic_model/data/label_${Labels}" \
  'question_file_name:.*' "question_file_name: %(Merlin)s/misc/questions/${QuestionFile}" \
  'mgc\s*:.*' 'mgc: 60' \
  'dmgc\s*:.*' 'dmgc: 180' \
  'lf0\s*:.*' 'lf0: 1' \
  'dlf0\s*:.*' 'dlf0: 3' \
  'vocoder_type\s*:.*' "vocoder_type: ${Vocoder}" \
  'samplerate\s*:.*' "samplerate: ${SamplingFreq}"

# Label-specific acoustic settings
case "${Labels}" in
  state_align)
    ${SED} -i 's#subphone_feats:.*#subphone_feats: full#' "${acoustic_config_file}"
    ;;
  phone_align)
    ${SED} -i 's#subphone_feats:.*#subphone_feats: coarse_coding#' "${acoustic_config_file}"
    ;;
  *)
    echo "ERROR: These labels (${Labels}) are not supported. Use state_align or phone_align!!" >&2
    exit 1
    ;;
esac

# Vocoder-specific acoustic settings
case "${Vocoder}" in
  STRAIGHT)
    apply_sed_substitutions "${acoustic_config_file}" \
      'bap\s*:.*' 'bap: 25' \
      'dbap\s*:.*' 'dbap: 75'
    ;;
  WORLD)
    case "${SamplingFreq}" in
      16000)
        apply_sed_substitutions "${acoustic_config_file}" \
          'bap\s*:.*' 'bap: 1' \
          'dbap\s*:.*' 'dbap: 3'
        ;;
      48000)
        apply_sed_substitutions "${acoustic_config_file}" \
          'bap\s*:.*' 'bap: 5' \
          'dbap\s*:.*' 'dbap: 15'
        ;;
      *)
        echo "ERROR: Unsupported SamplingFreq (${SamplingFreq}) for Vocoder WORLD." >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "ERROR: This vocoder (${Vocoder}) is not supported. Please configure yourself!!" >&2
    exit 1
    ;;
esac

# Sampling Frequency-specific acoustic settings
case "${SamplingFreq}" in
  16000)
    apply_sed_substitutions "${acoustic_config_file}" \
      'framelength\s*:.*' 'framelength: 1024' \
      'minimum_phase_order\s*:.*' 'minimum_phase_order: 511' \
      'fw_alpha\s*:.*' 'fw_alpha: 0.58'
    ;;
  22050)
    apply_sed_substitutions "${acoustic_config_file}" \
      'framelength\s*:.*' 'framelength: 1024' \
      'minimum_phase_order\s*:.*' 'minimum_phase_order: 511' \
      'fw_alpha\s*:.*' 'fw_alpha: 0.65'
    ;;
  44100)
    apply_sed_substitutions "${acoustic_config_file}" \
      'framelength\s*:.*' 'framelength: 2048' \
      'minimum_phase_order\s*:.*' 'minimum_phase_order: 1023' \
      'fw_alpha\s*:.*' 'fw_alpha: 0.76'
    ;;
  48000)
    if [[ "${Vocoder}" == "WORLD" ]]; then
      apply_sed_substitutions "${acoustic_config_file}" \
        'framelength\s*:.*' 'framelength: 2048' \
        'minimum_phase_order\s*:.*' 'minimum_phase_order: 1023'
    else
      apply_sed_substitutions "${acoustic_config_file}" \
        'framelength\s*:.*' 'framelength: 4096' \
        'minimum_phase_order\s*:.*' 'minimum_phase_order: 2047'
    fi
    ${SED} -i 's#fw_alpha\s*:.*#fw_alpha: 0.77#' "${acoustic_config_file}"
    ;;
  *)
    echo "ERROR: This sampling frequency (${SamplingFreq}) has never been tested before. Please configure yourself!!" >&2
    exit 1
    ;;
esac

# Architecture-specific acoustic settings
if [[ "${Voice}" == *"demo"* ]]; then
  apply_sed_substitutions "${acoustic_config_file}" \
    'hidden_layer_size\s*:.*' 'hidden_layer_size: [512, 512, 512, 512]' \
    "hidden_layer_type\s*:.*" "hidden_layer_type: [''TANH'', ''TANH'', ''TANH'', ''TANH'']"
fi

# Data-specific acoustic settings
apply_sed_substitutions "${acoustic_config_file}" \
  'train_file_number\s*:.*' "train_file_number: ${Train}" \
  'valid_file_number\s*:.*' "valid_file_number: ${Valid}" \
  'test_file_number\s*:.*' "test_file_number: ${Test}"

echo "Acoustic configuration settings stored in ${acoustic_config_file}"

exit 0
