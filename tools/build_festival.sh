
#!/bin/bash

# Build Festival from root folder.

cd tools/festival;
# git apply ../ff.cc.patch; # already included in repo
./configure;
make;
make install
make default_voices