## Install all Python dependencies along with Bandmat, which is not available through pip
# Replace 'package_name' with the actual name of the Python package
package_name="bandmat"

# We uninstall bandmat because it is sensitive to other package distributions.
if pip show "$package_name" &> /dev/null; then
    echo "Package '$package_name' is already installed. Uninstalling..."
    python -m pip uninstall -y $package_name # remove any already existing bandmat installs
else
    echo "Package '$package_name' is not installed."
fi

# Ensure proper python is selected.
tar -zxf wheelhouse.tar.gz 2> /dev/null || tar -zxf tools/tar.gz/wheelhouse.tar.gz 2> /dev/null # wheelhouse contains pkgs/
if [[ -d pkgs/ ]]; then
    echo "Install from pkgs/"
    
    # install the packages from pkgs
    python -m pip install -r requirements.txt --no-index --find-links pkgs/
    ## Install Bandmat, Need numpy and cython!
    git clone https://github.com/MattShannon/bandmat.git || cp -r pkgs/bandmat ./bandmat

else
    echo "Install from network"

    # create wheelhouse when online, for offline scenarios
    python -m pip download -r requirements.txt -d pkgs/
    git clone https://github.com/MattShannon/bandmat.git pkgs/bandmat
    tar -zcf wheelhouse.tar.gz pkgs/

    # install the packages in the regular way
    python -m pip install -r requirements.txt
fi

cp -r pkgs/bandmat bandmat 2> /dev/null

if [[ -d bandmat ]]; then
    cd bandmat
    # Using Numpy 3.X requires this update
    sed -i 's/cnp.int_t/cnp.int64_t/g' ./bandmat/misc.pyx
 

    python setup.py build_ext --inplace
    python setup.py install # venv no --user
    cd ..
    rm -rf bandmat/
fi

echo "Installed all Python dependencies"
