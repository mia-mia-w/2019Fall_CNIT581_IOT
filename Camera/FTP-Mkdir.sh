#!/bin/bash
# 1 = Server
# 2 = MotionDir
# 3 = Date
ftp -4 "$1" <<EOD
cd "$2"
mkdir "$3"
bye
EOD
