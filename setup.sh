#!/bin/sh
echo "Corrigiendo permisos de archivos Mosquitto..."

# Corregir permisos del passwd
sudo chown mosquitto:mosquitto ./mosquitto/config/passwd
sudo chmod 600 ./mosquitto/config/passwd

# Corregir permisos del ACL
sudo chmod 700 ./mosquitto/config/acl

# Corregir permisos de certificados
sudo chown -R mosquitto:mosquitto ./certs
sudo find ./certs -type f -exec chmod 644 {} \;
sudo find ./certs -type d -exec chmod 755 {} \;

echo "Permisos corregidos. Ahora puedes correr docker compose up sin problemas."
