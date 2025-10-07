#!/bin/bash
################################################################################
#
#   SCRIPT NAME: config_utils.sh
#   AUTHOR:      Ryan McCoppin
#
#   DESCRIPTION:
#       A library of utility functions for editing configuration files in Bash.
#       This script is designed to be sourced by other scripts to provide
#       reusable functionality. It includes a robust, cross-platform function
#       for performing multiple in-place search-and-replace operations using
#       GNU sed, with automatic handling for macOS environments where 'gsed'
#       is required.
################################################################################

# --- Functions ---

# --- SED Check ---
SED=sed
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v gsed &> /dev/null; then
    error_exit "GNU sed (gsed) is required on macOS.  Install it with 'brew install gnu-sed'."
  fi
  SED=gsed
fi

# Function to handle errors and exit
error_exit() {
  echo "ERROR: $1" >&2  # Send error to stderr
  exit 1
}

# Function to apply SED substitutions from an array
apply_sed_substitutions() {
  local config_file="$1"
  shift # Remove config_file from the arguments

  local -a args=("$@") # create a local array from the arguments
  local num_args=$#

  for ((i=0; i<num_args; i+=2)); do
    local search="${args[i]}"
    local replace="${args[i+1]}"
    ${SED} -i "s#${search}#${replace}#g" "$config_file"
  done
}
