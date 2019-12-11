#!/bin/bash
# 1 = EdgeServer
# 2 = EdgeMotionDir
# 3 = Date
# 4 = Video
ftp -4 "$1" <<EOD
cd "$2/$3"
put "$4.txt"
bye
EOD
