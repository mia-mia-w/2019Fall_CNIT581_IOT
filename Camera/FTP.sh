#!/bin/bash
# 1 = Server
# 2 = MotionDir
# 3 = Date
# 4 = Video
ftp -4 "$1" <<EOD
cd "$2/$3"
put "$4
bye
EOD
