#!/bin/bash

#----------------Static-Variables------------------------
$T = "false" # Meant to never end the script
$UniFiDir = "/var/lib/unifi-video/videos"
$EdgeServer = "192.168.1.45"
$EdgeUser = "pi"
$EdgePassword = "<don't insert real password here ever on GitHub>"

#----------------Main-----------------------------
While ( $T = "true" ); Do
	inotifywait -r -e close_write -t 20 $UniFiDir | While read $WrittenFile; Do # Checks recursively for 20 seconds if any file has been written and closed for any number of cameras
	  $Date = date +%m-%d-%Y-%H-%M # Get date in a nice format
	  Touch "~/$Date.txt" # Create notification message to alert the farmer rather than wait for the large video file to transfer
	  Ftp -4 -i user $EdgeUser $EdgePassword put "./$Date.txt" "$EdgeServer:/motion-notification" # FTP a notification of motion to the edge server to beginning notification of the farmer
	  rm "./$Date.txt" # Clean up the local notification
	  Ftp -4 -i user $EdgeUser $EdgePassword put $WrittenFile $EdgeServer:/motion # FTP the motion video file to the edge server
	Done
Done
