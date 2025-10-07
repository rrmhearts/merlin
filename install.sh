set -a
# export all these variables!
source .env
set +a

line_to_add='source $HOME/merlin/tools/bashrc.sh'
if ! grep -qF "$line_to_add" ~/.bashrc; then
  echo "$line_to_add" >> ~/.bashrc
fi

APT_CMD=$(which apt)

if [[ ! -z $APT_CMD ]]; then

    if ! python3.10 --version 2>&1 > /dev/null; then
        sudo add-apt-repository ppa:deadsnakes/ppa
        sudo apt update
        sudo apt install software-properties-common -y
        sudo apt install python3.10-full python3.10-dev python3.10-venv    || 
        sudo apt install python3-full python3-dev python3-venv python3-pip || 
        { 
            echo "Failed to install python, please ensure Python 3 is fully installed before continuing";
            echo "Update /install.sh with how to install Python 3"
            sleep 5; #exit 1;
        }
    fi
    # Sudo package requirements
    sudo apt install python-is-python3
    sudo apt install gcc g++ make zip unzip autotools-dev cmake csh libtool
    sudo apt install build-essential pkg-config libncurses5-dev libncursesw5-dev
    sudo apt install libx11-dev libsndfile1-dev libcurses-ocaml libxml2-dev libxslt-dev 
    # sudo apt install libcusolver-12-6 libcufft-12-6 libopenblas-dev libcudnn8-dev  libcublas-11-8

    # libcusparse.so.11 libcusolver.so.11 libcurand.so.10 libcufft.so.10 libnvinfer.so.7 libcusparse.so.11
    # wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
    # sudo dpkg -i cuda-keyring_1.1-1_all.deb
    # sudo apt-get update
    # sudo apt-get -y install cudnn-cuda-12

fi
# If you're not using a virtual environment, remove this line
# . ./activate_venv.sh # assume user can decide

LINE='export PATH="${HOME}/.local/bin:${PATH}"'
FILE=~/.bashrc
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

block='
# Function to check internet connection
check_internet() {
  ping -q -c 1 8.8.8.8 > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "online"
  else
    echo "offline"
  fi
}

export ESTDIR=/home/ryan/merlin/./tools/speech_tools
export FESTVOXDIR=/home/ryan/merlin/./tools/festvox
export FLITEDIR=/home/ryan/merlin/./tools/flite
export SPTKDIR=/home/ryan/merlin/./tools/SPTK
export PATH=/home/ryan/merlin/./tools/speech_tools/bin:${PATH}
export PATH=/home/ryan/merlin/./tools/festival/bin:${PATH}
'
if grep -qF "$block" ~/.bashrc; then
  echo "exports already exists in ~/.bashrc"
else
  echo "$block" >> ~/.bashrc
  echo "exports added to ~/.bashrc"
  source ~/.bashrc

fi

echo "$block" >> ~/.bashrc

# Options to install one or the other, or all (default)
if [[ "$1" == "py"* ]]; then
  # Install all python packages!
    ./install_pypkgs.sh
elif [[ "$1" == "to"* ]]; then
    # Install tools
    ./tools/compile_tools.sh 
    ./tools/compile_other_speech_tools.sh 
    ./tools/compile_htk.sh
else

    # Install all python packages!
    ./install_pypkgs.sh

    # No Theano, removed patch

    # Install tools
    ./tools/compile_tools.sh 
    ./tools/compile_other_speech_tools.sh 
    ./tools/compile_htk.sh
fi