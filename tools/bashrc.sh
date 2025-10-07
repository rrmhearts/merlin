# Function to check internet connection
check_internet() {
  ping -q -c 1 8.8.8.8 > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "online"
  else
    echo "offline"
  fi
}
export -f check_internet

export HTKDIR=${HOME}/merlin/tools/bin/htk
export ESTDIR=${HOME}/merlin/./tools/speech_tools
export FESTVOXDIR=${HOME}/merlin/./tools/festvox
export FLITEDIR=${HOME}/merlin/./tools/flite
export SPTKDIR=${HOME}/merlin/./tools/SPTK
export PATH=${HOME}/merlin/./tools/speech_tools/bin:${PATH}
export PATH=${HOME}/merlin/./tools/festival/bin:${PATH}
# export LD_LIBRARY_PATH=${HOME}/.local/lib/python3.10/site-packages/nvidia/cuda_runtime/lib/:$LD_LIBRARY_PATH
export PATH="${HOME}/.local/bin:${PATH}"

# Add all subdirectories to path
#bin_dir=${HOME}/merlin/tools/bin/
#export PATH=$(find $bin_dir -type d -print | tr '\n' ':' | sed 's/:*$//'):$PATH
