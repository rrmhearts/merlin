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
    tar -zcf wheelhouse.tar.gz pkgs/

    # install the packages in the regular way
    python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    python -m pip install -r requirements.txt

    echo "Creating wheelhouse..."
    tar -zcf wheelhouse.tar.gz pkgs/
fi

echo "Installed all Python dependencies"
