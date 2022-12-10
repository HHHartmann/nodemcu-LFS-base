{
	"filename": {
		"version": 123,
		"action": "reboot/none",
    "filesize": 123
	}
}


note: all sync sends are UDP broadcasts

At boot:
  Initiate SyncCheck

Initiate SyncCheck:
  read current state table
##  if file_is_not_there_physically     
##    Download
  Send current state table

Receive SyncCheck:
  check against own state table
  If has_newer_files 
    wait random timespan (0-1 sec)
    if no suficchient update info has been sent by other receiver
      send partial state table with updated files
  If has_older_files
    Download

the download filename is something like "{version}_{filename}.part"
Watch out for max filename length

Download:
  if download file does not exist
    create download file
  Continue Download

Continue Download:
  send stream request with start block to server which sent newer file information (first block is 1 as allways in lua)
  # might make sense to use/enhance http server for that
  # implement filter part to "auth" download requests
  
Receive Stream Request:
  send required blocks in ascending order
  ## each message contain filename and block
  ## or see above for tcp usage


Receive Stream Block:
  Write to file
  if file has correct length
    if file has correct checksum
      rename in place
      update current state table
      perform action (reboot/none)
      Initiate SyncCheck
    else
      set downloaded file to 0 bytes length


Possible states at boot after reset

started file exists
  will continue to download after SyncCheck. If no answer it will just remain in Place.



In dev, files are uploaded by other mechanisms.
To deploy them a function is called which checks the hashes of all local files against the current state table.
If the hash differs a new version is created by incrementing the "version", replacing the hash and calling `Initiate SyncCheck`.
To add entirely new files another function is called.
