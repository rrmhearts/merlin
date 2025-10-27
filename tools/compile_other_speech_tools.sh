#!/bin/bash

#########################################
######### Install Dependencies ##########
#########################################
#sudo apt-get -y install libncurses5 libncurses5-dev libcurses-ocaml # for sudo users only

current_working_dir=$(pwd)
tools_dir=${current_working_dir}/$(dirname $0)
cd $tools_dir
mkdir -p tar.gz/

remove_festival_speech_tools=true
install_speech_tools=true
install_festival=true
install_festvox=true
install_flite=true

export USER_CXXFLAGS="-fPIE"
export USER_CFLAGS="-fPIE"
export CPPFLAGS="-fPIE"
export CXXFLAGS="-fPIE"
export CFLAGS="-fPIE"

if [ "$remove_festival_speech_tools" = true ]; then
    echo "Removing speech tools and festival"
    rm -rf speech_tools
fi

# 1. Get and compile speech tools
if [ "$install_speech_tools" = true ]; then

    echo "downloading speech tools..."
    # speech_tools_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/speech_tools-2.4-release.tar.gz
    speech_tools_git=https://github.com/rrmhearts/speech_tools
    git clone $speech_tools_git 

    echo "compiling speech tools..."
    (
        cd speech_tools;
        find . -type f -exec dos2unix {} \; # make sure it is unix style
        make clean # very important when switching versions of gcc
        ./configure;
        make;
        make install
    )
fi

# export paths
export ESTDIR=$tools_dir/speech_tools
export LD_LIBRARY_PATH=$ESTDIR/lib:$LD_LIBRARY_PATH
export PATH=$ESTDIR/bin:$PATH

# 2. Get and compile festival, download dicts and some voices
if [ "$install_festival" = true ]; then
    echo "downloading festival..."
    rm -rf festival
    festival_git=https://github.com/rrmhearts/festival.git
    git clone $festival_git

    echo "compiling festival..."
    (
        cd festival;
        find . -type f -exec dos2unix {} \; # make sure it is unix style

        make clean # very important when switching versions of gcc
        ./configure;
        make;
        make install
        make default_voices
    )
fi

# export paths
export FESTDIR=$tools_dir/festival
export PATH=$FESTDIR/bin:$PATH

# 3. Get and compile festvox
if [ "$install_festvox" = true ]; then
    echo "downloading festvox..."
    # festvox_url=http://festvox.org/festvox-2.7/festvox-2.7.0-release.tar.gz
    festvox_git=https://github.com/festvox/festvox
    git clone $festvox_git

    tar -czf festvox.tar.gz festvox/
    mv festvox.tar.gz tar.gz/ 2>/dev/null

    echo "compiling festvox..."
    (
        cd festvox;
        ./configure;
        make;
    )
fi

# export paths
export FESTVOXDIR=$tools_dir/festvox

echo "deleting downloaded tar files..."
mv $tools_dir/*.tar.gz $tools_dir/tar.gz/
# rm -rf $tools_dir/*.tar.gz
# find $tools_dir/*.tar.gz -type f -not -name 'festival.tar.gz' -delete

if [[ ! -f ${ESTDIR}/bin/ch_track ]]; then
    echo "Error installing speech tools"
    exit 1
elif [[ ! -f ${FESTDIR}/bin/festival ]]; then
    echo "Error installing Festival"
    exit 1
elif [[ ! -f ${FESTVOXDIR}/src/vc/build_transform ]]; then
    echo "Error installing Festvox"
    exit 1
else
    echo "All tools successfully compiled!!"
fi

# 5. Get and compile flite
if [ "$install_flite" = true ]; then
    echo "downloading flite..."
    # speech_tools_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/speech_tools-2.4-release.tar.gz
    flite_git=http://github.com/festvox/flite
    git clone $flite_git
    tar -czf flite.tar.gz flite/
    mv flite.tar.gz tar.gz/ 2>/dev/null

    echo "compiling speech tools..."
    (
        cd flite;
        ./configure;
        make;
    )
fi

LINE="export ESTDIR=$tools_dir/speech_tools"
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
LINE="export FESTVOXDIR=$tools_dir/festvox"
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
LINE="export FLITEDIR=$tools_dir/flite"
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
LINE="export SPTKDIR=$tools_dir/SPTK"
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

LINE="export PATH=$tools_dir/speech_tools/bin:"'${PATH}'
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
LINE="export PATH=$tools_dir/festival/bin:"'${PATH}'
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

FILE="$HOME/.bashrc"
LINE='export PATH=${HOME}/.local/bin:${PATH}'
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# Clean up
mv *.tar.gz tar.gz/ 2>/dev/null
rm HTS* 2>/dev/null
