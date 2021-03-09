#!/bin/bash

# Part 1 Check environment
# only show Release, CPU, Memory

if [ -e "/etc/redhat-release" ]
then
	cat /etc/redhat-release
else
	echo "/etc/redhat-release is not existed."
	exit 1
fi

if [ -e "/proc/cpuinfo" ]
then
	cat /proc/cpuinfo | grep "cpu cores" | uniq
else
	echo "/proc/cpuinfo is not existed."
	exit 1
fi

if [ -e "/proc/meminfo" ]
then
	cat /proc/meminfo | grep "MemTotal"
else
	echo "proc/meminfo is not existed."
	echo 1
fi

sudo setenforce 0
echo "Selinux set permissive."

# Copy files
# The installation files put in the ~ directory. Copy the installation directory to /var/wp_deploy.

sudo cp -r ~/wp_deploy /var/
echo "Copy to var directory"
cd /var/wp_deploy
echo "Go to /var/wp_deploy directory"
sudo mkdir -p /var/wp_deploy/mysql/data
echo "Create for mysql data directory"

# Part 2 Installation
# 2.1 Nginx installation

sudo yum -y update
echo "Yum updated."
sudo yum install -y yum-utils
#sudo cat ./conf/nginx.repo > /etc/yum.repos.d/nginx.repo
sudo yum-config-manager --add-repo ./conf/nginx.repo
sudo yum -y install nginx
echo "Nignx installed"
if [ -s "/etc/nginx/nginx.conf" ]
then
	sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
	sudo cp ./conf/nginx.conf /etc/nginx/
	sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
	sudo cp ./conf/conf.d/* /etc/nginx/conf.d
	echo "Set the nginx config."
else
	echo "Nginx installation is failure."
	exit 1
fi

if [ -s "/usr/sbin/nginx" ] 
then 
	sudo systemctl start nginx
	echo "Nginx is running..."
else
	echo "Nignx is not installed."
	exit 1
fi

# 2.2 Docker installation

sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
docker --version
if [ $? -ne 0 ] 
then 
	echo "Docker installation is failure."
	exit 1
else
	echo "Docker installed."
	sudo systemctl start docker
	echo "Docker is running..."
fi
sudo cp ./conf/daemon.json /etc/docker/
echo "Copied the daemon.json to /etc/docker."

# 2.3 Docker-compose installation
sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
docker-compose --version
if [ $? -ne 0 ] 
then 
	echo "Docker-compose installation is failure."
	exit 1
else
	echo "Docker-compose installed."
fi

# Part 3 Launch
# Before launching, please change the name and passwd in yml file.
# and check that the port 80, 8080, 443 are available.
# and change the SSL setting in localhost443.conf.bak of nginx

cd /var/wp_deploy
echo "Go to /var/wp_deploy"
sudo docker-compose up -d
echo "All done."




