#!/bin/sh
###########################################################################
##                                                                       ##
##                   Carnegie Mellon University                          ##
##                         Copyright (c) 2017                            ##
##                        All Rights Reserved.                           ##
##                                                                       ##
##  Permission is hereby granted, free of charge, to use and distribute  ##
##  this software and its documentation without restriction, including   ##
##  without limitation the rights to use, copy, modify, merge, publish,  ##
##  distribute, sublicense, and/or sell copies of this work, and to      ##
##  permit persons to whom this work is furnished to do so, subject to   ##
##  the following conditions:                                            ##
##   1. The code must retain the above copyright notice, this list of    ##
##      conditions and the following disclaimer.                         ##
##   2. Any modifications must be clearly marked as such.                ##
##   3. Original authors' names are not deleted.                         ##
##   4. The authors' names are not used to endorse or promote products   ##
##      derived from this software without specific prior written        ##
##      permission.                                                      ##
##                                                                       ##
##  CARNEGIE MELLON UNIVERSITY AND THE CONTRIBUTORS TO THIS WORK         ##
##  DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING      ##
##  ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT   ##
##  SHALL CARNEGIE MELLON UNIVERSITY NOR THE CONTRIBUTORS BE LIABLE      ##
##  FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES    ##
##  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN   ##
##  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,          ##
##  ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF       ##
##  THIS SOFTWARE.                                                       ##
##                                                                       ##
###########################################################################
##                                                                       ##
##  Install FestVox voice building suite from github                     ##
##                                                                       ##
##  You *must* add the four environment variables FESTVOXDIR, ESTDIR,    ##
##  SPTKDIR and FLITEDIR in order for voice builds to work               ##
##                                                                       ##
###########################################################################

# Ubuntu (and related) prerequisites:
# sudo apt-get install git build-essential libncurses5-dev sox
# sudo apt-get install csh doxygen xsltproc graphviz

# Get source (unstable)
# git clone http://github.com/festvox/speech_tools
# git clone http://github.com/festvox/festival
# git clone http://github.com/festvox/festvox
# git clone http://github.com/festvox/flite

# wget http://festvox.org/packed/SPTK-3.6.tar.gz
# tar zxvf SPTK-3.6.tar.gz

# export ESTDIR=`pwd`/speech_tools
# export FLITEDIR=`pwd`/flite
# export FESTVOXDIR=`pwd`/festvox
# export SPTKDIR=`pwd`/SPTK

# # Compile source
# mkdir SPTK
# patch -p0 <festvox/src/clustergen/SPTK-3.6.patch 
# cd SPTK-3.6
# ./configure --prefix=$SPTKDIR
# make
# make install
# cd ..

# cd speech_tools
# ./configure
# make
# make test
# cd ..

# cd festival
# ./configure
# make
# make default_voices
# cd ..

# cd festvox
# ./configure
# make
# cd ..

# cd flite
# ./configure
# make
# cd ..

# ## Add to $HOME/.bashrc
# echo export ESTDIR=$ESTDIR
# echo export FLITEDIR=$FLITEDIR
# echo export FESTVOXDIR=$FESTVOXDIR
# echo export SPTKDIR=$SPTKDIR

# exit


## Make voices

# clunits
mkdir cmu_us_awb_clunits
cd cmu_us_awb_clunits
$FESTVOXDIR/src/unitsel/setup_clunits cmu us awb
$FESTVOXDIR/src/prosody/setup_prosody
wget http://festvox.org/packed/data/cmu/awb100.tar.bz2
tar jxvf awb100.tar.bz2
./bin/build_clunits_voice
./flite/flite_cmu_us_awb "A whole joy was reaping, but they've gone south, you should fetch azure mike." flite/whole_awb.wav
cd ..

mkdir cmu_us_rms_clunits
cd cmu_us_rms_clunits
$FESTVOXDIR/src/unitsel/setup_clunits cmu us rms
$FESTVOXDIR/src/prosody/setup_prosody
wget http://festvox.org/packed/data/cmu/rms100.tar.bz2
tar jxvf rms100.tar.bz2
./bin/build_clunits_voice
./flite/flite_cmu_us_rms "A whole joy was reaping, but they've gone south, you should fetch azure mike." flite/whole_rms.wav
cd ..

# clustergen
mkdir cmu_us_awb_cg
cd cmu_us_awb_cg
$FESTVOXDIR/src/clustergen/setup_cg cmu us awb
wget http://festvox.org/packed/data/cmu/awb100.tar.bz2
tar jxvf awb100.tar.bz2
./bin/build_cg_voice
./flite/flite_cmu_us_awb "A whole joy was reaping, but they've gone south, you should fetch azure mike." flite/whole_awb.wav
cd ..

mkdir cmu_us_rms_cg
cd cmu_us_rms_cg
$FESTVOXDIR/src/clustergen/setup_cg cmu us rms
wget http://festvox.org/packed/data/cmu/rms100.tar.bz2
tar jxvf rms100.tar.bz2
./bin/build_cg_rfs_voice
# Build a flite voice from this build
rm -rf flite
$FLITEDIR/tools/setup_flite
./bin/build_flite cg
cd flite
make
cd ..
./flite/flite_cmu_us_rms "A whole joy was reaping, but they've gone south, you should fetch azure mike." flite/whole_rms.wav
cd ..

# voice conversion
mkdir cmu_us_awb_vc
cd cmu_us_awb_vc
$FESTVOXDIR/src/unitsel/setup_clunits cmu us awb
wget http://festvox.org/packed/data/cmu/awb100.tar.bz2
tar jxvf awb100.tar.bz2
$FESTVOXDIR/src/vc/build_transform setup
$FESTVOXDIR/src/vc/build_transform default_us
./bin/do_build build_prompts_waves etc/txt.transform.data
$FESTVOXDIR/src/vc/build_transform train
$FESTVOXDIR/src/vc/build_transform festvox

. etc/voice.defs

$ESTDIR/../festival/bin/festival -b festvox/${FV_VOICENAME}_transform.scm \
	    "(voice_${FV_VOICENAME}_transform)" \
	        '(utt.save.wave (SynthText "A whole joy was reaping, but they'"'"'ve gone south, you should fetch azure mike.") "whole.wav")'

cd ..

ls -altr cmu_us_*_cg/flite/whole*.wav
ls -altr cmu_us_*_clunits/flite/whole*.wav
ls -altr cmu_us_*_vc/whole*.wav

