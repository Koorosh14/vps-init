#!/usr/bin/env bash
# Run with "-y" or "-n" parameter if you want to answer the rest of the prompts. (Except the prompt about Let's Encrypt)

read -p "You have to change the hostname manually. Have you done that? [y/n] " yn
if [ "$yn" != "Y" ] && [ "$yn" != "y" ]
then
	exit;
fi

apt-get update

#declare -a PKGS=(build-essential make dkms dbus nano zip unzip wget curl man-db acpid apache2)
#for i in "${PKGS[@]}"
#do
#	sudo apt-get -y --ignore-missing install "$i"
#done
# Let's run them all together to reduce the amount of printed messages
sudo apt-get -y --ignore-missing install build-essential make dkms dbus nano zip unzip wget curl man-db acpid
sudo apt-get -y --ignore-missing install apache2

# If no parameter exists or the first parameter is not "-y"
if [ -z "$1" ] || { [ "$1" != "-Y" ] && [ "$1" != "-y" ]; }
then
	read -p "Disable firewall? [y/n] " yn
fi
if [ "$1" == "-Y" ] || [ "$1" == "-y" ] || [ "$yn" == "Y" ] || [ "$yn" == "y" ]
then
	sudo ufw disable
fi

if [ -z "$1" ] || { [ "$1" != "-Y" ] && [ "$1" != "-y" ]; }
then
	read -p "Change timezone to Tehran? [y/n] " yn
fi
if [ "$1" == "-Y" ] || [ "$1" == "-y" ] || [ "$yn" == "Y" ] || [ "$yn" == "y" ]
then
	sudo timedatectl set-timezone Asia/Tehran
	echo "Timezone changed to Tehran"
fi

if [ -z "$1" ] || { [ "$1" != "-Y" ] && [ "$1" != "-y" ]; }
then
	read -p "Harden Apache? [y/n] " yn
fi
if [ "$1" == "-Y" ] || [ "$1" == "-y" ] || [ "$yn" == "Y" ] || [ "$yn" == "y" ]
then
	if grep -qxF "ServerSignature On" /etc/apache2/apache2.conf
	then
		sed -i "s/ServerSignature On/#ServerSignature On/" /etc/apache2/apache2.conf
	fi

	if ! grep -qiF "My changes" /etc/apache2/apache2.conf
	then
		echo "" >> /etc/apache2/apache2.conf
		echo "" >> /etc/apache2/apache2.conf
		echo "" >> /etc/apache2/apache2.conf
		echo "### My changes:" >> /etc/apache2/apache2.conf
		echo "<Directory /var/www/html>" >> /etc/apache2/apache2.conf
		echo "	Options -Indexes" >> /etc/apache2/apache2.conf
		echo "</Directory>" >> /etc/apache2/apache2.conf
	fi
	if ! grep -qxF "ServerSignature Off" /etc/apache2/apache2.conf
	then
		echo "ServerSignature Off" >> /etc/apache2/apache2.conf
	fi
	if ! grep -qxF "ServerTokens Prod" /etc/apache2/apache2.conf
	then
		echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
	fi

	# Check if the file exists
	if test -f /etc/apache2/sites-available/000-default.conf
	then
		if ! grep -qiF "My changes" /etc/apache2/sites-available/000-default.conf
		then
			echo "" >> /etc/apache2/sites-available/000-default.conf
			echo "" >> /etc/apache2/sites-available/000-default.conf
			echo "" >> /etc/apache2/sites-available/000-default.conf
			echo "### My changes:" >> /etc/apache2/sites-available/000-default.conf
		fi

		if ! grep -qF "Options Indexes FollowSymLinks MultiViews" /etc/apache2/sites-available/000-default.conf
		then
			echo "<Directory /var/www/>" >> /etc/apache2/sites-available/000-default.conf
			echo "	Options Indexes FollowSymLinks MultiViews" >> /etc/apache2/sites-available/000-default.conf
			echo "	AllowOverride All" >> /etc/apache2/sites-available/000-default.conf
			echo "	Order allow,deny" >> /etc/apache2/sites-available/000-default.conf
			echo "	allow from all" >> /etc/apache2/sites-available/000-default.conf
			echo "</Directory>" >> /etc/apache2/sites-available/000-default.conf
		fi
	fi

	echo "Apache security increased"
fi
sudo service apache2 restart

read -p "Install 3x-ui? (DO NOT RE-INSTALL if you've already installed it before!) [y/n] " yn
if [ "$yn" == "Y" ] || [ "$yn" == "y" ]
then
	bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
	echo "3X-UI installed"

	read -p "WARP will begin installing now. Select a port for WireProxy when you got prompt to. [Press any key to continue]"
	bash <(curl -sSL https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh)
	echo "WARP installed"
fi

read -p "Do you want to install Let's Encrypt? (DO NOT CHOOSE YES if it's already installed, it'll fuck up your Apache!) [y/n] " yn
if [ "$yn" == "Y" ] || [ "$yn" == "y" ]
then
	sudo add-apt-repository -y ppa:certbot/certbot
	sudo apt install -y certbot python3-certbot-apache

	if ! test -f /etc/apache2/sites-available/000-default.conf
	then
		echo "000-default.conf not exists!"
		exit
	fi
	if ! grep -qF "ServerName " /etc/apache2/sites-available/000-default.conf
	then
		echo "Invalid syntax in 000-default.conf!"
		exit
	fi

	read -p "Type in your [sub]domain address: " ServerName
	# If the server name is not already exists in the file
	# -E = Regular expression
	if ! grep -qxE "\s*ServerName ${ServerName}" /etc/apache2/sites-available/000-default.conf
	then
		# Comment all previous ServerNames
		# /g = Global (Replace all)
		sed -i "s/\n\s*ServerName /#ServerName /g" /etc/apache2/sites-available/000-default.conf
		sed -i "s/##ServerName /#ServerName /g" /etc/apache2/sites-available/000-default.conf

		# Add the new server name before the commented one(s)
		sed -i "s/#ServerName /ServerName ${ServerName}\n#ServerName/" /etc/apache2/sites-available/000-default.conf
	fi

	sudo systemctl reload apache2

	read -p "Certbot will begin installing now. Type an E-Mail > Agree terms > Decline E-mail sharing > When prompted to select a virtual host, select the one with HTTPS > When prompted about redirecting, select No redirect. [Press any key to continue]"
	sudo certbot --apache -d "$ServerName" -d www."$ServerName"

	sudo systemctl reload apache2
	echo "Let's Encrypt installed"
fi



# Sources:
# https://unix.stackexchange.com/a/729875/
# https://stackoverflow.com/a/226724/
# https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html
# https://stackoverflow.com/a/6482403/
# https://stackoverflow.com/a/11287896/
# https://askubuntu.com/a/837386/
# https://stackoverflow.com/a/3557165/
# https://unix.stackexchange.com/a/77278/
# https://stackoverflow.com/a/66470822/
# https://kodekloud.com/blog/check-file-in-bash/
# https://stackoverflow.com/a/15849152/
# https://www.linuxquestions.org/questions/programming-9/grep-ignoring-spaces-or-tabs-817034/
