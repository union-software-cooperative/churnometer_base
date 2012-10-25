Churnometer is a dashboard and data warehouse for interactively exploring a union's growth and decline.

INSTALLATION

While we've been developing on osx and ubuntu, we've only written installation script for Ubuntu server 12.04.  

Until we publish our source code under GPLv3 Affero licensing you will need a git hub account and be a collaborator on churnometer_base.

Contact lukerohde@freechange.com.au to get added as a collaborator

UBUNTU 12.04

The installation on Ubuntu 12.04 is done by running the install script located at git@github.com:/lukerohde/churnometer_base/install/install.  

Download this file. 
$ chmod 755 ./install  
$ ./install 

It will download the source to /opt/churnometer, create a non-priviledged user for running the software, install postgres, ruby, git, thin& nginx.  It will also download and restore the demo data to postgres.  It is intended to be executed on a clean installation of ubuntu.  



