#!/bin/bash

#########################################
######### Install Dependencies ##########
#########################################
#sudo apt-get install csh realpath

tools_dir=$(dirname $0)
cd $tools_dir
mkdir -p tar.gz/

install_sptk=true
install_postfilter=true
install_world=true
install_reaper=true
install_magphase=true
remove_tarballs=false
internet_connection=$(check_internet)

if [ $internet_connection = "online" ]; then
  echo "Internet connection is available." $internet_connection
else
  echo "Internet connection is not available." $internet_connection
fi

# 1. Get and compile SPTK
if [ "$install_sptk" = true ]; then
    echo "downloading SPTK-3.9..."
    sptk_url=http://downloads.sourceforge.net/sp-tk/SPTK-3.9.tar.gz
    if [ $internet_connection = "online" ]; then
        if hash curl 2>/dev/null; then
            curl -L -O $sptk_url
        elif hash wget 2>/dev/null; then
            wget $sptk_url
        fi
    else
        cp tar.gz/SPTK-3.9.tar.gz
    fi
    
    if [ -f "SPTK-3.9.tar.gz" ]; then
        echo "SPTK already downloaded."
    else
        echo "please download the SPTK-3.9 from $sptk_url"
        exit 1
    fi
    tar xzf SPTK-3.9.tar.gz

    echo "compiling SPTK..."
    (
        cd SPTK-3.9;
        if ! grep -q 'struct bbmargin bbm;' ./bin/psgr/psgr.c;
        then
            echo "fixing psgr in SPTK"
            sed -i 's/} bbm;/};/g' ./bin/psgr/psgr.h
            # sed -i 's/"psgr.h"\n/struct bbmargin bbm;\n/g' ./bin/psgr/psgr.c
            sed -i '79 a struct bbmargin bbm;' ./bin/psgr/psgr.c
        fi
        ./configure --prefix=$PWD/build;
        make;
        make install
    )

    # Get and compile Postfilter
    if [ "$install_postfilter" = true ]; then
        if [ $internet_connection = "online" ]; then
            echo "downloading postfilter..."
            postfilter_url=http://104.131.174.95/downloads/tools/postfilter.tar.gz
            if hash curl 2>/dev/null; then
                curl -L -O $postfilter_url
            elif hash wget 2>/dev/null; then
                wget $postfilter_url
            fi
        else
            cp tar.gz/postfilter.tar.gz .
        fi
        
        if [ -f "postfilter.tar.gz" ]; then
            echo "postfilter.tar.gz already downloaded."
        else
            echo "please download the postfilter from $postfilter_url"
            exit 1
        fi
        tar xzf postfilter.tar.gz
        
        echo "compiling postfilter..."
        (
            # need automake 1.16.4 instead of 1.16.5
            if [ $internet_connection = "online" ]; then
                wget https://ftp.gnu.org/gnu/automake/automake-1.16.4.tar.gz
            else
                cp tar.gz/automake-1.16.4.tar.gz ./
            fi
            tar xvf automake-1.16.4.tar.gz
            cd automake-1.16.4/
            ./configure
            make
            sudo make install
            cd ../

            # now we can make postfilter
            cd ./postfilter/src;
            ./00_make.sh
        )
    fi
fi


# 2. Getting WORLD
if [ "$install_world" = true ]; then
    echo "compiling WORLD..."
    (
        cd WORLD;
        make
        make analysis synth
        make clean
    )
fi


# 3. Getting REAPER
if [ "$install_reaper" = true ]; then
    if [ "$internet_connection" = "online" ]; then
        # if we're removing the files, download it
        echo "downloading REAPER..."
        git clone https://github.com/google/REAPER.git
    fi
    echo "compiling REAPER..."
    (
        cd REAPER
        rm -rf build
        mkdir build   # In the REAPER top-level directory
        cd build
        cmake ..
        make
    )
fi

SPTK_BIN_DIR=bin/SPTK-3.9
WORLD_BIN_DIR=bin/WORLD
REAPER_BIN_DIR=bin/REAPER

# 4. Getting MagPhase vocoder:
if [ "$install_magphase" = true ]; then
    if [ "$internet_connection" = true ]; then
        echo "downloading MagPhase vocoder..."
        rm -rf magphase
        git clone https://github.com/CSTR-Edinburgh/magphase.git
    fi

    echo "configuring MagPhase..."
    (
        mkdir -p magphase/tools/bin
        cp --update SPTK-3.9/build/bin/b2mc   magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/bcp    magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/c2acr  magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/freqt  magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/mc2b   magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/mcep   magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/merge  magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/sopr   magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/vopr   magphase/tools/bin/
        cp --update SPTK-3.9/build/bin/x2x    magphase/tools/bin/
        cp --update REAPER/build/reaper       magphase/tools/bin/
    )
fi


if [ "$remove_tarballs" = true ]; then
    # 5. Copy binaries
    mkdir -p $tools_dir/tar.gz
    mv $tools_dir/*.tar.gz $tools_dir/tar.gz
    echo "deleting downloaded tar files..."
    rm -rf $tools_dir/*.tar.gz
fi

mkdir -p bin
mkdir -p $SPTK_BIN_DIR
mkdir -p $WORLD_BIN_DIR
mkdir -p $REAPER_BIN_DIR

cp SPTK-3.9/build/bin/* $SPTK_BIN_DIR/
cp postfilter/bin/* $SPTK_BIN_DIR/
cp WORLD/build/analysis $WORLD_BIN_DIR/
cp WORLD/build/synth $WORLD_BIN_DIR/
cp REAPER/build/reaper $REAPER_BIN_DIR/

if [[ ! -f ${SPTK_BIN_DIR}/x2x ]]; then
    echo "Error installing SPTK tools! Try installing dependencies!!"
    echo "sudo apt-get install csh"
    exit 1
elif [[ ! -f ${SPTK_BIN_DIR}/mcpf ]]; then
    echo "Error installing postfilter tools! Try installing dependencies!!"
    echo "sudo apt-get install realpath"
    echo "sudo apt-get install autotools-dev"
    echo "sudo apt-get install automake"
    exit 1
elif [[ ! -f ${WORLD_BIN_DIR}/analysis ]]; then
    echo "Error installing WORLD tools"
    exit 1
else
    echo "All tools successfully compiled!!"
fi
