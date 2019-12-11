#!/bin/bash
# 1 = EdgeServer
# 2 = EdgeMotionDir
# 3 = Date
ftp -4 "$1" <<EOD
cd "$2"
mkdir "$3"
bye
EOD
