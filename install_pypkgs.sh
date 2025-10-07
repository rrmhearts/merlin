## Install all Python dependencies
# Ensure proper python is selected.
tar -zxf wheelhouse.tar.gz 2> /dev/null || tar -zxf tools/tar.gz/wheelhouse.tar.gz 2> /dev/null # wheelhouse contains pkgs/
if [[ -d pkgs/ ]]; then
    echo "Install from pkgs/"
    
    # install the packages from pkgs
    python -m pip install -r requirements.txt --no-index --find-links pkgs/
else
    echo "Install from network"

    # create wheelhouse when online, for offline scenarios
    python -m pip download -r requirements.txt -d pkgs/
    tar -zcf wheelhouse.tar.gz pkgs/

    # install the packages in the regular way
    python -m pip install -r requirements.txt
fi

echo "Installed all Python dependencies"
