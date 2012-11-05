#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange) 
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.


INSTALLATION - UBUNTU 12.04 & 12.10

We've been developing on osx and ubuntu, and only written installation script for Ubuntu server 12.04 which also seems to work on 12.10.  

Until we publish our source code to the general public you will need a git hub account and be a collaborator on github.com for churnometer_base or churnometer_asu to download the source as part of the installation.  The ASU's source is at churnometer_asu.  For demo data you'll need to be collaborator on churnometer_data.

Contact lukerohde@freechange.com.au to get added as a collaborator to the project.

To install on Ubuntu 12.04 or 12.10, run the script located at git@github.com:/lukerohde/churnometer_base/install/install (You'll need to be a collaborator - see above) 

# Download the installer file from git@github.com:/lukerohde/churnometer_base/install/install or get from backup
$ chmod 755 ./install  
$ ./install install

It will download the source to /opt/churnometer, create a non-priviledged user (churnometer) for running the software, install postgres, ruby, git, thin& nginx.  It will also download and restore the demo data to postgres.  It is intended to be executed on a clean installation of ubuntu.  

The first step of the installation will allow you to override the default installation parameters.  You should at least set a different password for the churnometer account which by default will be 'mypassword'.

If you have a database backup, you can supply its file name to the install script as the second parameter. 

You will be prompted during the installation to copy the id_pub.rsa public key to your github.com account.  You will also be prompted to set your error email address using vim - press 'i' to edit, 'esc' to get out edit mode and ':wq' to save and quit  

$./install install ~/churnometer.sql

If you have a source backup, you can copy over /opt/churnometer and restart thin. NB override the source as the non-privileged user specified during the installation.  In this example, the user churnometer.
$ sudo su churnometer 
$ rm /opt/churnometer
$ mv ~/churnometer_backup /opt/churnometer
$ /etc/init.d/thin restart

CONFIGURATION 

This is still very technical.  When starting from scratch, you'll need to edit config.yaml.  Run /import?action=rebuild (remarked out in start.rb), then import three files via /import.  members.txt, transactions.txt and displaytext.txt.  We need some examples of these files.

DISASTER RECOVERY

Scenario 1 - restore database from backup (assuming data corruption)
copy database file from backup to server (from linux to linux - use winscp or cygwin on windows)
$ scp backup/churnometer_db_backup.sql churnometer@churnometer:~/
copy install script from backup to server (from linux to linux - use wincscp or cygwin on windows)
$ scp install/install churnometer@churnometer:~/
login to the server via ssh
$ ssh churnometer@churnometer
$ ~/install just-data ~/churnometer_db_backup.sql
accept Y for default options

Scenario 2 - starting from fresh ubuntu installation
copy backup to server
$ scp backup.zip yourusername@churnometer
login to the server via ssh
$ ssh yourusername@churnometer
unzip the backup
$ mkdir backup
$ cd backup
$ unzip ~/backup.zip
install everything
$ ~/backup/install/install install ~/backup/backup/churnometer_db_backup.sql
check/confirm proposed username, password - the source repo doesn't matter because we'll over right it
delete the downloaded source
$ sudo rm -Rf /opt/churnometer/*
restore the backup source
$ cp -R ~/backup/* /opt/churnometer/
restart the server
$ sudo -u churnometer /etc/init.d/thin restart
you're done




