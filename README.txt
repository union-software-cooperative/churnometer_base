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

This file is located in the root directory of the source code - /README.txt

INSTALLATION - UBUNTU 12.04 & 12.10

We've been developing on osx and ubuntu, and only written installation script for Ubuntu server 12.04 which also seems to work on 12.10.  

Until we publish our source code to the general public you will need a git hub account and be a collaborator on github.com for churnometer_base or churnometer_asu to download the source as part of the installation.  The ASU's source is at git@github.com:lukerohde/churnometer_asu.  For demo data you'll need to be collaborator on churnometer_data.

Contact lukerohde@freechange.com.au to get added as a collaborator to the project.

To install on Ubuntu 12.04 or 12.10, run the script located at git@github.com:/lukerohde/churnometer_base/install/install (You'll need to be a collaborator - see above) 

# Download the installer file from git@github.com:/lukerohde/churnometer_base/install/install or get from backup
$ chmod 755 ./install  
$ ./install install

It will download the source to /opt/churnometer, create a non-priviledged user (churnometer) for running the software, install postgres, ruby, git, thin& nginx.  It will also download and restore the demo data to postgres.  It is intended to be executed on a clean installation of ubuntu.  

The first step of the installation will allow you to override the default installation parameters.  You should at least set a different password for the churnometer account which by default will be 'mypassword'.

You will be prompted during the installation to copy the id_pub.rsa public key to your github.com account.  You will also be prompted to set your error email address using vim - press 'i' to edit, 'esc' to get out edit mode and ':wq' to save and quit  

If you have a database backup, you can supply its file name to the install script as the second parameter. 

$./install install ~/churnometer.sql

If you have a source backup, you can copy over /opt/churnometer and restart thin. NB override the source as the non-privileged user specified during the installation.  In this example, the user churnometer.
$ sudo su churnometer 
$ rm /opt/churnometer/*
$ cp -R ~/churnometer_backup/* /opt/churnometer/
$ /etc/init.d/thin restart

CONFIGURATION 

Initial configuration is still very technical
- Prepare database queries for members.txt, transactions.txt and displaytext.txt (TODO file format examples - public/asu/*.sql) 
- Create CSV files from each of these queries (see public/asu/churnometer_export.vbs for an example - BCP can also be used for SQL server)
- Edit config/config.yaml to define the dimensions of your members.txt file - this can be accessed via http://churnometer/config
- Once saved via the we you'll be prompted to confirm/change the database updates.  After this, the system will rebuild to your schema
- Test your import, one file at a time at http://churnometer/import
- Automate the import - see public/asu/churnometer_export.vbs

Tweaking column headings, descriptions and user logins
- You can browse to http://churnometer/config, after saving, the system will restart
- To restart the system after editing config.yaml - http://churnometer/restart
- Restarting might appear to crash - this usually just means it is taking longer to restart then the count down.  Try refreshing again.

DISASTER RECOVERY

Backup
- A backup of the database and source code can be downloaded from http://churnometer/backup
- It is a good idea to take a backup to disk (where it will be archived) after each import
- This can be automated as part of the export/import ( see public/asu/churnometer_export.vbs)

The following disaster recovery procedures require terminal access to the machine running churnometer.  
From Windows there are two ways to achieve this - using either putty or cygwin.  You can use winscp to copy files to linux.

If you don't have winscp you can browse to the windows share for the webserver \\churnometer\production

Scenario 1 - restore database from backup (assuming data corruption) using install script
copy database file from backup to server (from linux to linux - use winscp or cygwin on windows)
$ scp data_backup/churnometer_db_backup.sql churnometer@churnometer:~/
copy install script from backup to server (from linux to linux - use wincscp or cygwin on windows)
$ scp install/install churnometer@churnometer:~/
login to the server via ssh
$ ssh churnometer@churnometer
$ ~/install just-data ~/churnometer_db_backup.sql
accept Y for default options

Scenario 2 - restore database from backup using terminal
copy database file from backup to server (from linux to linux - use winscp or cygwin on windows)
$ scp data_backup/churnometer_db_backup.sql churnometer@churnometer:~/
disconnect users from churnometer database on postgres 9.2 (optional)
$ sudo -u postgres psql -c "select pg_terminate_backend(pid) from pg_stat_activity where datname = 'churnometer'; "
OR disconnect users from churnometer database on postgres 9.1 (optional)
$ sudo -u postgres psql -c "select pg_terminate_backend(procpid) from pg_stat_activity where datname = 'churnometer'; "
drop existing churnometer database (optional)
$ sudo -u postgres psql -c "drop database if exists churnometer; "
create a churnometer database - you can change the database name to anything
$ sudo -u postgres psql -c "create database churnometer;"
restore the data 
$ sudo -u postgres psql churnometer < ~/churnometer_db_backup.sql
update the config file to point to the new database if you renamed it
$ vim /opt/churnometer/config/config.yaml

Scenario 3 - starting from fresh ubuntu installation
copy backup to server
$ scp backup.zip yourusername@churnometer
login to the server via ssh
$ ssh yourusername@churnometer
unzip the backup
$ mkdir backup
$ cd backup
$ unzip ~/backup.zip
install everything
$ ~/backup/install/install install ~/backup/data_backup/churnometer_db_backup.sql
check/confirm proposed username, password - the source repo doesn't matter because we'll over right it
delete the downloaded source
$ sudo rm -Rf /opt/churnometer/*
restore the backup source
$ cp -R ~/backup/* /opt/churnometer/
restart the server
$ sudo -u churnometer /etc/init.d/thin restart
you're done
