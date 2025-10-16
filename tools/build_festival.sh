
#!/bin/bash

# Build Festival from root folder.
# festival_url=http://www.cstr.ed.ac.uk/downloads/festival/2.4/festival-2.4-release.tar.gz
# festival_git=https://github.com/festvox/festival.git
# git clone $festival_git
# tar -xzf festival.tar.gz -C tmp # using the code extraction caused errors.

cd festival
# git apply ../ff.cc.patch; # already included in repo
./configure;
make;
make install
make default_voices