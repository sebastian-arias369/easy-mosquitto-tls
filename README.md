# Mosquitto con TLS y autenticación usando Docker Compose

Este tutorial explica cómo levantar un servidor MQTT con Mosquitto utilizando Docker Compose. El servidor usa TLS con certificados de Let's Encrypt y autenticación de usuarios con ACLs.

## 🧾 Requisitos previos

1. Un dominio válido apuntando al servidor (ejemplo: `maquina.dominio.com`).
2. Acceso root al servidor.
3. Tener los puertos **80** (HTTP) y **8883** (MQTT sobre TLS) abiertos en el firewall.
4. Tener instalado **Docker** y **Docker Compose**.

---

## 📁 Estructura del proyecto

```plaintext
mqtt-project/
├── acl -> mosquitto/config/acl
├── certs/
│   ├── archive/...
│   └── live/...
├── compose.yml
├── mosquitto/
│   ├── config/
│   │   ├── acl
│   │   ├── certs/ISRG_Root_X1.pem
│   │   ├── mosquitto.conf
│   │   ├── passwd (se genera)
│   │   └── users.txt
│   ├── data/
│   ├── log/mosquitto.log
│   └── run/
├── users.txt -> mosquitto/config/users.txt
├── .env
```

### Contenido de `.env`

```env
DOMAIN=maquina.dominio.com
EMAIL=tu_correo@dominio.com
```

### Contenido de `users.txt`

```txt
alvaro:12345
juan:abcde
admin1:admin123
admin:admin1234
```

### Contenido de `acl`

```txt
pattern read +/+/+/+/%u/in
pattern readwrite +/+/+/+/%u/out

user admin
topic readwrite #

user admin2
pattern write +/+/+/+/%u/in
pattern read +/+/+/+/%u/out
```
---

## 🧪 Paso a paso

### 1. Clonar el proyecto o crear la estructura anterior

Asegúrese de tener el contenido anterior creado en tu servidor bajo `~/mqtt-project`.

```bash
git clone 
```

### 3. Crear el archivo `.env`

```bash
echo "DOMAIN=maquina.dominio.com" > .env
echo "EMAIL=tu_correo@dominio.com" >> .env
```

### 4. Verificar que el dominio apunte al servidor

Ejemplo:

```bash
dig +short maquina.dominio.com
```

### 5. Ejecutar el stack

#### Primer uso (generación inicial de certificados)

**1. Corre solo certbot para generar el certificado**

```bash
docker compose up certbot
```

Este paso solicitará un nuevo certificado TLS si no existe.

**2. Corre el script `setup.sh` para corregir permisos**

```bash
chmod +x setup.sh
./setup.sh
```

Este script ajustará los permisos de los certificados y archivos necesarios para que `mosquitto` funcione correctamente.

**3. Ahora puedes levantar Mosquitto**

```bash
docker compose up mosquitto
```

✅ Mosquitto arrancará usando el certificado TLS emitido.

---

#### Uso posterior (con certificados ya emitidos)

Si ya tienes certificados, simplemente ejecuta:

```bash
./setup.sh
docker compose up
```

Esto corregirá permisos si es necesario y levantará el broker directamente.

---

#### Notas de seguridad

- No publiques llaves privadas (`privkey.pem`).
- Asegúrate de no dejar archivos sensibles sin proteger.
- `users.txt` contiene contraseñas en texto plano y solo debe existir temporalmente para crear el archivo `passwd`. **Elimina `users.txt` después de la primera creación** si es posible.

---

#### `.gitignore` recomendado

Dentro de `certs/`, crea un archivo `.gitignore` que contenga:

```
*
!.gitignore
```

Esto evitará subir los certificados reales a GitHub accidentalmente.


## 📡 Pruebas con MQTT


Para conectarte al servidor MQTT desde otro equipo con TLS como suscriptor:

```bash
sudo mosquitto_sub -h maquina.dominio.com -p 8883 -u admin -P admin1234 \
  -t "test/topic" --tls-version tlsv1.2
```


Para conectarte al servidor MQTT desde otro equipo con TLS como publicador:

```bash
sudo mosquitto_pub -h maquina.dominio.com -p 8883 -u admin -P admin1234 \
  -t "test/topic" --tls-version tlsv1.2 -m "Encender"
```

Debera ver el mensaje `Encender` en el shell del suscriptor.

---

## 🔄 Renovación automática del certificado

Let's Encrypt renueva certificados cada 60-90 días. Para automatizar utilice cron:

```bash
(crontab -l ; echo "0 3 * * * docker compose run --rm certbot") | crontab -
```

Esto verifica a diario a las 3 AM si se debe renovar el certificado.

---

## ✅ Verificar funcionamiento

```bash
docker logs mosquitto_tls
```

Verifica que no haya errores como:
- Permisos del archivo `passwd`
- Errores en la conexión TLS
- Problemas con ACLs

---

## 🧽 Tips útiles

- Para borrar todo y volver a iniciar (esto tambien borra los certificados):

```bash
docker compose down -v
sudo rm -rf certs/* mosquitto/config/passwd mosquitto/config/mosquitto.conf
```

- Para dejar el log en blanco:

```bash
sudo tee mosquitto/log/mosquitto.log <<< "" > /dev/null
```

---

## 🔐 Listas de control de acceso `acl` en Mosquitto

`acl` significa **Access Control List** (Lista de Control de Acceso).

Sirve para **definir qué usuarios pueden publicar (`write`) o suscribirse (`read`)** a ciertos tópicos MQTT.

Mosquitto evalúa este archivo después de verificar que el usuario ingresó con credenciales válidas. Con esto se asegura de **limitar el acceso a datos sensibles o privados**.

---

## Ejemplo

### Diseño del formato del topico para usuarios autenticados usando `pattern`

```text
pattern read +/+/+/+/%u/in
pattern readwrite +/+/+/+/%u/out
```

Define reglas dinámicas que aplican **a todos los usuarios autenticados**.

- `%u` será reemplazado automáticamente por el nombre de usuario del cliente que se conecta.
- El símbolo `+` representa un nivel de tópico.

Por tanto, cada usuario:
- Podrá **leer** mensajes en su canal `.../<usuario>/in`.
- Podrá **leer y publicar** en su canal `.../<usuario>/out`.

Se diseño este patrón para que el formato de los topicos tenga el siguiente formato:

```plaintext
<pais>/<estado>/<ciudad>/<device-id>/<usuario>/out  // Para publicaciones
<pais>/<estado>/<ciudad>/<device-id>/<usuario>/in   // Para suscripciones
```

Un ejemplo para estos topicos es:

```
colombia/valle/tulua/ESP32-CC50E3B65DD/device1/out  # publicación
colombia/valle/tulua/ESP32-CC50E3B65DD/device1/in   # suscripción
```

Este formato de topicos trae varias ventajas importantes, especialmente en sistemas distribuidos, escalables y 
seguros. A continuacion se explican las ventajas de esta estrategia:

---

#### 🔹 1. **Organización geográfica clara**

- Facilita la administración de los datos y dispositivos por región, estado y ciudad.
- Permite aplicar reglas de seguridad, filtros, dashboards y análisis por ubicación.

Ejemplo:
```plaintext
colombia/valle/tulua/... → todos los dispositivos en Tuluá
```

---

##### 🔹 2. **Escalabilidad modular**

- Puedes agregar nuevos países, ciudades o dispositivos sin cambiar la estructura general.
- Cada nivel (`pais`, `estado`, `ciudad`, `device-id`, `usuario`) es fácilmente filtrable o agrupable.

---

#### 🔹 3. **Facilidad para aplicar ACLs personalizadas**

- Gracias al uso de `%u` en ACLs, puedes permitir que cada usuario solo lea o escriba en su ruta específica:

```plaintext
pattern read +/+/+/+/%u/in
pattern readwrite +/+/+/+/%u/out
```

Esto:
- Limita accesos.
- Aumenta la seguridad.
- Simplifica la gestión de permisos.

---

#### 🔹 4. **Compatibilidad con dashboards o analítica**

- Sistemas como Grafana, Node-RED o InfluxDB pueden usar los niveles para etiquetar, filtrar o visualizar datos por zona, usuario o dispositivo.

---

#### 🔹 5. **Soporte para múltiples dispositivos por usuario y viceversa**

- El `device-id` identifica unívocamente cada hardware (ESP32, Raspberry Pi, etc).
- El `usuario` identifica al dueño o controlador del dispositivo.

Esto te da flexibilidad para:
- Monitorear múltiples dispositivos de un usuario.
- Compartir dispositivos entre varios usuarios (si lo defines en ACL).

---

#### 🔹 6. **Estándar profesional y mantenible**

- Mantener convenciones claras y jerárquicas es una buena práctica en arquitecturas MQTT (especialmente con brokers empresariales como Mosquitto, HiveMQ, EMQX, etc).
- Hace el sistema fácil de entender para nuevos desarrolladores o integradores.


---

### Usuario con acceso total

```text
user admin
topic readwrite #
```

- El usuario `admin` puede leer y publicar en **todos los tópicos** (`#` es comodín de múltiples niveles).
- Útil para dashboards, administración o pruebas.

---

### Usuario con permisos cruzados


```text
user admin2
pattern write +/+/+/+/%u/in
pattern read +/+/+/+/%u/out
```

- `admin2` puede:
  - **escribir** comandos al canal `.../usuario/in` de otros.
  - **leer** las respuestas en `.../usuario/out`.

Este usuario está diseñado para escenarios donde un controlador necesita:

- **Escribir comandos** hacia múltiples dispositivos.
- **Leer respuestas** desde los dispositivos.

En otras palabras, tiene permisos para interactuar con los tópicos `in` y `out` de otros usuarios.

