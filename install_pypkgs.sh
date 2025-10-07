## Install all Python dependencies along with Bandmat, which is not available through pip

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-only)
      echo "Using local copies only"
      tar -zxf wheelhouse.tar.gz # wheelhouse contains pkgs/
      shift
      ;;
    *)
      echo "Argument: $1"
      shift
      ;;
  esac
done

packages_dir=$(find . -type d \( -name "packages" -o -name "pkgs" -o -name ".pkgs" \) -print -maxdepth 1)

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
if [[ -d $packages_dir ]]; then
    echo "Install from $packages_dir"
    # install the packages from pkgs
    python -m pip install torch torchvision torchaudio --no-index --find-links $packages_dir/
    python -m pip install -r requirements.txt --no-index --find-links $packages_dir/
else
    echo "Install from network"

    # create wheelhouse when online, for offline scenarios
    python -m pip download -r requirements.txt -d pkgs/
    git clone https://github.com/MattShannon/bandmat.git pkgs/bandmat 2> /dev/null
    # For Keras 3
    # python -m pip download torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 -d pkgs
    tar -zcf wheelhouse.tar.gz pkgs/

    # install the packages in the regular way
    python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    python -m pip install -r requirements.txt

    echo "Creating wheelhouse..."
    tar -zcf wheelhouse.tar.gz pkgs/
fi

## Install Bandmat, Need numpy and cython!
echo "Installing bandmat..."
cp -r $packages_dir/bandmat ./bandmat 2> /dev/null || git clone https://github.com/MattShannon/bandmat.git 2> /dev/null

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
