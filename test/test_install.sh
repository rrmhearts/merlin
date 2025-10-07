#!/bin/bash
# Script for testing the installation of Merlin pipeline
# python modules are checked, libraries versions, basic theano calls, etc.
# This script has to be run in its directory, as shows the usage.

if test "$#" -ne 0; then
    echo "Usage: ./test_install.sh"
    exit 1
fi

# Source install-related environment variables
source .env


# Start checking versions

echo -n "Python version: "
python -c 'import sys; print("version "+sys.version.replace("\n",""))'
if [[ "$?" == "0" ]]; then echo "OK"; else echo "No python installed      FAILED"; fi
echo " "

echo -n "Python Numpy version: "
python -c 'import numpy; print("version "+numpy.version.version)'
if [[ "$?" == "0" ]]; then echo "OK"; else echo "numpy not accessible  FAILED"; fi
echo " "
