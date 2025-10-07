#!/bin/bash

# --- Configuration ---
GLOBAL_CONFIG="$1"
SCRIPT_NAME=$(basename "$0")

# --- Source Utility Functions & SED check ---
SED=sed
source "$(dirname "$0")/config_utils.sh" || error_exit "Failed to source config_utils.sh"

# --- Argument Validation ---

if [[ $# -ne 1 ]]; then
  echo "Usage: ./${SCRIPT_NAME} conf/global_settings_adapt.cfg"
  exit 1
fi

if [[ ! -f "${GLOBAL_CONFIG}" ]]; then
  error_exit "Global config file '${GLOBAL_CONFIG}' does not exist."
fi

# --- Load Global Configuration ---
source "$(dirname "$0")/../../.env"
source "${GLOBAL_CONFIG}" || error_exit "Failed to source global config file."

# --- Configuration File Generation ---

# --- Duration Configuration ---

duration_config_file="conf/duration_${Voice}_${AdaptationMethod}.conf"
duration_demo_config="$WorkDir/conf/general/duration_demo.conf"

# Copy base configuration
if [[ -f "${duration_demo_config}" ]]; then
  cp -f "${duration_demo_config}" "${duration_config_file}"
else
  error_exit "Duration demo config file '${duration_demo_config}' not found."
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
  'question_file_name:.*' "question_file_name: %(Merlin)s/misc/questions/${QuestionFile}" \
  'hidden_layer_size\s*:.*' 'hidden_layer_size: [1024, 1024, 1024, 1024, 1024, 1024]' \
  'train_file_number\s*:.*' "train_file_number: ${Train}" \
  'valid_file_number\s*:.*' "valid_file_number: ${Valid}" \
  'test_file_number\s*:.*' "test_file_number: ${Test}" \
  'model_file_name\s*:.*' "model_file_name: model_adapted_using_${AdaptationMethod}"

# Adaptation Method specific settings
case "${AdaptationMethod}" in
  lhuc)
    apply_sed_substitutions "${duration_config_file}" \
      "hidden_layer_type\s*:.*" "hidden_layer_type: [''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'']" \
      'start_from_trained_model\s*:.*' "start_from_trained_model: ${DurTrainedModel}" \
      'use_lhuc\s*:.*' 'use_lhuc:True'
    ;;
  aux|fine_tune)
    apply_sed_substitutions "${duration_config_file}" \
      "hidden_layer_type\s*:.*" "hidden_layer_type: [''TANH'', ''TANH'', ''TANH'', ''TANH'', ''TANH'', ''TANH'']" \
      'start_from_trained_model\s*:.*' "start_from_trained_model: ${DurTrainedModel}"
    ;;
  *)
    echo "ERROR: Unsupported AdaptationMethod (${AdaptationMethod})." >&2
    exit 1
    ;;
esac

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

echo "Duration configuration settings stored in ${duration_config_file}"

# --- Acoustic Configuration ---

acoustic_config_file="conf/acoustic_${Voice}_${AdaptationMethod}.conf"
acoustic_demo_config="$WorkDir/conf/general/acoustic_demo.conf"

# Copy base configuration
if [[ -f "${acoustic_demo_config}" ]]; then
  cp -f "${acoustic_demo_config}" "${acoustic_config_file}"
else
  error_exit "Acoustic demo config file '${acoustic_demo_config}' not found."
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
  'samplerate\s*:.*' "samplerate: ${SamplingFreq}" \
  'hidden_layer_size\s*:.*' 'hidden_layer_size: [1024, 1024, 1024, 1024, 1024, 1024]' \
  'train_file_number\s*:.*' "train_file_number: ${Train}" \
  'valid_file_number\s*:.*' "valid_file_number: ${Valid}" \
  'test_file_number\s*:.*' "test_file_number: ${Test}" \
  'model_file_name\s*:.*' "model_file_name: model_adapted_using_${AdaptationMethod}"

# Adaptation Method specific settings
case "${AdaptationMethod}" in
  lhuc)
    apply_sed_substitutions "${acoustic_config_file}" \
      "hidden_layer_type\s*:.*" "hidden_layer_type: [''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'', ''TANH_LHUC'']" \
      'start_from_trained_model\s*:.*' "start_from_trained_model: ${AcTrainedModel}" \
      'use_lhuc\s*:.*' 'use_lhuc:True'
    ;;
  aux|fine_tune)
    apply_sed_substitutions "${acoustic_config_file}" \
      "hidden_layer_type\s*:.*" "hidden_layer_type: [''TANH'', ''TANH'', ''TANH'', ''TANH'', ''TANH'', ''TANH'']" \
      'start_from_trained_model\s*:.*' "start_from_trained_model: ${AcTrainedModel}"
    ;;
  *)
    echo "ERROR: Unsupported AdaptationMethod (${AdaptationMethod})." >&2
    exit 1
    ;;
esac

# Label-specific acoustic settings
case "${Labels}" in
  state_align)
    ${SED} -i 's#subphone_feats\s*:.*#subphone_feats: full#' "${acoustic_config_file}"
    ;;
  phone_align)
    ${SED} -i 's#subphone_feats\s*:.*#subphone_feats: coarse_coding#' "${acoustic_config_file}"
    ;;
  *)
    echo "ERROR: These labels (${Labels}) are not supported. Use state_align or phone_align!!" >&2
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
    echo "ERROR: This sampling frequency (${SamplingFreq}) never tested before...please configure yourself!!" >&2
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

echo "Acoustic configuration settings stored in ${acoustic_config_file}"

exit 0
