echo "[*] installing JDK"
sudo apt install default-jdk

echo "[*] downloading tomcat"
cd /tmp; wget https://downloads.apache.org/tomcat/tomcat-10/v10.0.6/bin/apache-tomcat-10.0.6.tar.gz

echo "[*] creating tomcat user"
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

echo "[*] creating tomcat path"
mkdir /opt/tomcat

echo "[*] extracting tomcat"
sudo tar xzvf apache-tomcat-10.0.6.tar.gz -C /opt/tomcat --strip-components=1
cd /opt/tomcat

echo "[*] applying permissions"
sudo chown -R tomcat webapps/ work temp/ logs
sudo chmod -R g+r /opt/tomcat/conf
sudo chgrp -R tomcat /opt/tomcat

echo "[*] permissions applied, tomcat installed!"
echo "[*] starting tomcat"

sh /opt/tomcat/bin/startup.sh

echo "[*] tomcat installation completed"
echo "[*] installing SSL cert"

apt-get install software-properties-common
add-apt-repository ppa:certbot/certbot
apt-get install certbot

printf "default domain: "
read default_domain

printf "password: "
read cert_password

certbot certonly --standalone -d ${default_domain}
cd /etc/letsencrypt/live/${default_domain}

echo "[*] creating JKS cert"
openssl pkcs12 -export -out /tmp/${default_domain}_fk.p12 -in /etc/letsencrypt/live/${default_domain}/fullchain.pem -inkey /etc/letsencrypt/live/${default_domain}/privkey.pem -name tomcat
keytool -importkeystore -deststorepass ${cert_password} -destkeypass ${cert_password} -destkeystore /tmp/${default_domain}.jks -srckeystore /tmp/${default_domain}_fk.p12 -srcstoretype PKCS12 -srcstorepass ${cert_password} -alias tomcat

cp /tmp/${default_domain}.jks /opt/tomcat/conf
cd /opt/tomcat/conf
chown tomcat:tomcat *.jks

echo "[*] creation completed, add JKS cert path '/opt/tomcat/conf/${default_domain}.jks' to server.xml"
echo "[*] make sure to add attribute certificateKeystorePassword=\"${cert_password}\""

echo "[*] installing authbind, to unlock permissions to port 80 & 443"
sudo apt-get install authbind

sudo touch /etc/authbind/byport/80
sudo touch /etc/authbind/byport/443

sudo chmod 777 /etc/authbind/byport/80
sudo chmod 777 /etc/authbind/byport/443

echo "[*] patching tomcat startup to use authbind."
sed -i "s/exec \"\$PRGDIR\"/exec authbind --deep \"\$PRGDIR\"/g" /opt/tomcat/bin/startup.sh

echo "[*] startup patched, restarting tomcat"
sh /opt/tomcat/bin/shutdown.sh
sh /opt/tomcat/bin/startup.sh

path='/opt/tomcat/webapps/ROOT/index.jsp'
result=""

while read line; do
  trim=$(echo $line | sed 's/ //g')
  if [ "$trim" = "<imgsrc=\"tomcat.png\"alt=\"[tomcatlogo]\"/>" ]; then
    result="${result}<img alt=\"[tomcat logo]\" src=\"https://i.imgur.com/hhEVOqV.png\" style=\"height: 80px; image-rendering: crisp-edges;\">"
  else
    result="${result}${line}"
  fi
done < $path
> $filename
echo $result >> $filename


echo "[*] COMPLETED"

# possibly soon to be automated
echo "things to do:"
echo "1. change port 8080 in server.xml to 80"
echo "2. uncomment HTTPS connector, change jks path to '/opt/tomcat/conf/${default_domain}.jks'"
echo "3. add certificateKeystorePassword=\"${cert_password}\" to https connector"
echo "4. change 8443 HTTPS port to 443"
echo "5. reboot tomcat"
