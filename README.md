(c) 2022 Linbedded Pawel Suchanecki

Savy.sh
=======

Brief
-----
Bash scripts to list and schedule "by-date" file transfers of big collections over SSH. 

Purpose
-------
Designed to securely transfer your media from mobile to the target location & ensuring all data was properly copied before removing it from mobile device.

Special use
-----------
Devices with degraded NAND (internal storage) unable to list all entries in a big media storage directory, usually resulting in freezing of the connection.


More info
---------
`generate_filelist.sh` - Connects to given SSH host and lists files matching the given (date) pattern in given directory.  Having that list it generates
a set of SFTP and Bash scirpts for each day that COPY, VERIFY and REMOVE files from source, target and source (respectively). 
These files are called "rules" and there is a special mechanics that prevents removing from source if not everything was copied properly to target.

`rules-runner.sh` - Provided with a directory (rules are generated into directories - one directory per each day/date) of rules this scripts generates 
one-time execution script `r.sh` that automates running all 3 scripts (copy, verify & remove).


Use cases
---------

Case #0 (common for all)

You don't want to transfer over USB cable. You want to be able to move around with your mobile while the transfer is in progress.


Case #1.

Imagine your mobile's internal memory (NAND) is not very responsive when you try to list all your media (pics and videos) when preparing to transfer them.
This tool will allow you to query the big collection for names specific to given date or date ranges.
With that you can transfer the media day by day, possibly identifing the place where internal memory is corrupted and ommit that area when transfering.


Case #2.

Imagine you have gigabytes of photos on your mobile and need to transfer some reasonable amout out of it to free some space (possibly for new photos :P).
You can start transferring from the oldest or any particularly interesting period.  AND you will make sure all content is secured before removing precious content from 
the temporary storage (mobile)


Case #3. 

You don't want to use/install proprietary apps for your transferrs.

