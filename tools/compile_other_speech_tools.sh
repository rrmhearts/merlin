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
internet_connection=$(check_internet)

if [ $internet_connection = "online" ]; then
  echo "Internet connection is available." $internet_connection
else
  echo "Internet connection is not available." $internet_connection
fi

export USER_CXXFLAGS="-fPIE"
export USER_CFLAGS="-fPIE"
export CPPFLAGS="-fPIE"
export CXXFLAGS="-fPIE"
export CFLAGS="-fPIE"

# no longer needed
REinstall_speech_tools=true

# REMEMBER, speech_tools will need re-built on certain changes
# to Festival. Often this is required! See documentation?
if [ "$remove_festival_speech_tools" = true ]; then
    echo "Removing speech tools and festival"
    rm -rf speech_tools
fi

# 1. Get and compile speech tools
if [ "$install_speech_tools" = true ]; then

    if [ $internet_connection = "online" ]; then
        echo "downloading speech tools..."
        # speech_tools_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/speech_tools-2.4-release.tar.gz
        speech_tools_git=https://github.com/festvox/speech_tools
        git clone $speech_tools_git 
    else
        cp tar.gz/speech_tools.tar.gz .
        tar xzf speech_tools.tar.gz
    fi
    # Patching speech tools may prevent readline errors, but it may also cause featival to seg fault. Suggest not using.
    # git clone $speech_tools_git && sed -i 's/#define USE_TERMCAP/#ifdef SYSTEM_IS_WIN32\n#define USE_TERMCAP\n#endif/g' ./speech_tools/siod/editline.h
    
    # IF these lines are still commented out, uncomment them to build speech_tools.
    sed -i 's/\/\/int getch(void);/int getch(void);/g' ./speech_tools/include/EST_Token.h
    sed -i 's/\/\/EST_TokenStream \&getch(char \&C);/EST_TokenStream \&getch(char \&C);/g' ./speech_tools/include/EST_Token.h

    echo "compiling speech tools..."
    (
        cd speech_tools;
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
    # Festival is now included in Merlin. No longer need to download!
    # echo "downloading festival..."
    # festival_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/festival-2.4-release.tar.gz
    # festival_git=https://github.com/festvox/festival.git
    # git clone $festival_git
    # tar -xzf festival.tar.gz # using the code extraction caused errors.
    echo "compiling festival..."
    (
        cd festival;
        # patch is applied in downloaded version
        # patch -p1 < ../ff.cc.patch # work with non-git
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
    if [ $internet_connection = "online" ]; then
        echo "downloading festvox..."
        # festvox_url=http://festvox.org/festvox-2.7/festvox-2.7.0-release.tar.gz
        festvox_git=https://github.com/festvox/festvox
        git clone $festvox_git

        tar -czf festvox.tar.gz festvox/
        mv festvox.tar.gz tar.gz/ 2>/dev/null
    else
        cp tar.gz/festvox.tar.gz . 2>/dev/null
        tar xzf festvox.tar.gz 2>/dev/null
    fi

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
    if [ $internet_connection = "online" ]; then
        echo "downloading flite..."
        # speech_tools_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/speech_tools-2.4-release.tar.gz
        flite_git=http://github.com/festvox/flite
        git clone $flite_git
        tar -czf flite.tar.gz flite/
        mv flite.tar.gz tar.gz/ 2>/dev/null
    else
        cp tar.gz/flite.tar.gz . 2>/dev/null
        tar xzf flite.tar.gz 2>/dev/null
    fi

    echo "compiling speech tools..."
    (
        cd flite;
        ./configure;
        make;
    )
fi

# 6. Rebuild speech_tools without rebuilding festival
# This is for VoiceServer to work. This will break festival if it is rebuilt with this as dependency.
if [ "$REinstall_speech_tools" = true ]; then
    echo "reinstall speech tools..."
    # speech_tools_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/speech_tools-2.4-release.tar.gz
    # speech_tools_git=https://github.com/festvox/speech_tools
    # git clone $speech_tools_git 
    # Patching speech tools may prevent readline errors, but it may also cause featival to seg fault. Suggest not using.
    sed -i 's/#define USE_TERMCAP/#ifdef SYSTEM_IS_WIN32\n#define USE_TERMCAP\n#endif/g' ./speech_tools/siod/editline.h
    
    echo "compiling speech tools..."
    (
        cd speech_tools;
        make clean
        ./configure;
        make;
        make install
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
