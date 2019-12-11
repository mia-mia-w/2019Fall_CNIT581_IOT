#!/bin/bash
# 1 = EdgeServer
# 2 = EdgeNotificationsDir
# 3 = Date
ftp -4 "$1" <<EOD
cd "$2"
put "$3.txt"
bye
EOD
