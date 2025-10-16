#!/bin/bash
set -a  # all export

# Determine the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define the configuration variables
block="
######################################
############# PATHS ##################
######################################
MerlinDir=$SCRIPT_DIR
WorkDir=$PWD
######################################
############# TOOLS ##################
######################################
ESTDIR=$SCRIPT_DIR/tools/speech_tools
FESTDIR=$SCRIPT_DIR/tools/festival
FESTVOXDIR=$SCRIPT_DIR/tools/festvox
FLITEDIR=$SCRIPT_DIR/tools/flite
SPTKDIR=$SCRIPT_DIR/tools/SPTK
HTKDIR=$SCRIPT_DIR/tools/bin/htk
"

# Create the .env file (consider whether this is actually needed)
echo "$block" > "$PWD/.env"
#source "$PWD/.env"  # Sourcing only affects the current shell

set +a  # disable all export

# Add a line to .bashrc
line_to_add='source $HOME/merlin/tools/bashrc.sh'
if ! grep -qF "$line_to_add" "$HOME/.bashrc"; then
  echo "$line_to_add" >> "$HOME/.bashrc"
fi

# Check for Python 3.10
if ! python3 --version | grep -q "Python 3\.10"; then  # Corrected check

    echo "Python 3.10 not found.  Attempting installation..."
    APT_CMD=$(which apt)
    if [[ ! -z "$APT_CMD" ]]; then

        sudo add-apt-repository ppa:deadsnakes/ppa -y
        sudo apt update
        sudo apt install software-properties-common -y
        sudo apt install python3.10 python3.10-dev python3.10-venv -y ||
        sudo apt install python3-full python3-dev python3-venv python3-pip -y ||
        {
            echo "Failed to install python, please ensure Python 3 is fully installed before continuing"
            echo "Update /install.sh with how to install Python 3"
            sleep 5
            exit 1
        }

        # Sudo package requirements
        sudo apt install python-is-python3 -y
        sudo apt install gcc g++ make zip unzip autotools-dev cmake csh libtool -y
        sudo apt install build-essential pkg-config libncurses5-dev libncursesw5-dev -y
        sudo apt install libx11-dev libsndfile1-dev libcurses-ocaml libxml2-dev libxslt-dev -y
    fi
fi

# Ensure ~/.local/bin is in PATH
LINE='export PATH="${HOME}/.local/bin:${PATH}"'
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# Add Merlin-related exports to .bashrc (using SCRIPT_DIR for consistency)
block2="
export ESTDIR=$SCRIPT_DIR/tools/speech_tools
export FESTVOXDIR=$SCRIPT_DIR/tools/festvox
export FLITEDIR=$SCRIPT_DIR/tools/flite
export SPTKDIR=$SCRIPT_DIR/tools/SPTK
export PATH=$SCRIPT_DIR/tools/speech_tools/bin:\$PATH
export PATH=$SCRIPT_DIR/tools/festival/bin:\$PATH
"

if grep -qF "$block2" "$HOME/.bashrc"; then
  echo "Merlin exports already exist in ~/.bashrc"
else
  echo "$block2" >> "$HOME/.bashrc"
  echo "Merlin exports added to ~/.bashrc"
  source "$HOME/.bashrc"  # Source after adding (important!)
fi


# Install based on argument
if [[ "$1" == "py"* ]]; then
  ./install_pypkgs.sh
elif [[ "$1" == "to"* ]]; then
    ./tools/compile_tools.sh
    ./tools/compile_other_speech_tools.sh
    ./tools/compile_htk.sh
else
    ./install_pypkgs.sh
    ./tools/compile_tools.sh
    ./tools/compile_other_speech_tools.sh
    ./tools/compile_htk.sh
fi