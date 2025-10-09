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
##  To build an arctic voice use something like                          ##
##     sh ./do_arctic aew                                                ##
##                                                                       ##
##  See $ARCTIC_DB_DIR for list of datasets available                    ##
##                                                                       ##
###########################################################################

LANG=C; export LANG

if [ ! "$ESTDIR" ]
then
	   echo "environment variable ESTDIR is unset"
	      echo "set it to your local speech tools directory e.g."
	         echo '   bash$ export ESTDIR=/home/awb/projects/speech_tools/'
		    echo or
		       echo '   csh% setenv ESTDIR /home/awb/projects/speech_tools/'
		          echo 'Ensure you have set ESTDIR, FESTVOXDIR, SPTK and FLITEDIR'
			     echo 'See festvox.org/do_install for installing the FestVox Tools suite'
			        exit 1
fi

ARCTIC_DB_DIR=http://festvox.org/cmu_arctic/packed/
ARCTIC_DB_DIR=http://tts.speech.cs.cmu.edu/awb/cmu_arctic

# Set up voice
mkdir cmu_us_${1}
cd cmu_us_${1}
$FESTVOXDIR/src/clustergen/setup_cg cmu us ${1}

# Get waveforms and transcription
( cd recording &&
	  wget ${ARCTIC_DB_DIR}/cmu_us_${1}_arctic.tar.bz2 &&
	    tar jxvf cmu_us_${1}_arctic.tar.bz2
    )
    cp -pr recording/cmu_us_${1}_arctic/* .

    # Build voice
    $FESTVOXDIR/src/clustergen/build_cg_rfs_voice
