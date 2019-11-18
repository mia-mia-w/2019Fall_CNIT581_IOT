#!/bin/bash

#----------------Variables------------------------
$T = "false"
  # always run script
$FootageDir = "/etc/unifi"
$MotionDir = "/etc/unifi/motion"
$OldMotionDir = "/etc/old-unifi/oldmotion"
$LiveDir = "/etc/unifi/live"
$OldLiveDir = "/etc/old-unifi/oldlive"
$PiIP = "192.168.1.45"
$PiUser = "root"
$PiPassword = "encrypted-piece-of-shit"


#----------------Functions-------------------------
CheckWhenDone () {
  While ($ModifiedDate != Date -r "$file"); Do
    $ModifiedDate = Date -r "$file"
    Sleep 2
  Done
}


#----------------Main-----------------------------
While ( $T = "true" ); Do
inotifywait -m $MotionDir -e create | While read path action file; Do
  # test forever for any newly created files in $FootageDir recursively and perform an action after
  $Date = date
  Touch "./$Date-motion-notification.txt"
    # Create notification message
  Ftp -4 -i user $PiUser $PiPassword put "./$Date-motion-notification.txt" "$PiIP:/motion-notification"
    # Send notification (aka the txt) to the pi to trigger an alert to be sent to the farmer
  rm "./$Date-motion-notification.txt"
    # Clean up local notification
  $ModifiedDate = Date -r "$file"
    # Get the last modified date of the newly created file
  Sleep 2
  CheckWhenDone()
  Ftp -4 -i user $PiUser $PiPassword put $file $PiIP:/motion/
  mv $File $OldMotionDir
Done
