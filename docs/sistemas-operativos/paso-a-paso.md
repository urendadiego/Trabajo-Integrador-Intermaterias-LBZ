# Sistemas Operativos — paso a paso

Guía para dejar andando la demo en las 3 PCs, desde una VM de Ubuntu **recién instalada, sin nada**.
El porqué de cada decisión está en el [plan de SO](plan.md). Esta guía es solo el "qué hacer".

| Parte | Dónde | Quién |
| --- | --- | --- |
| [A. En Windows](#a-en-windows) | Windows + VS Code + VirtualBox | Los 3 |
| [B. En Ubuntu](#b-en-ubuntu-instalación-limpia) | Dentro de la VM | Los 3 |
| [C. Las IPs](#c-las-ips-una-sola-vez-entre-los-3) | Una persona en VS Code, los demás `git pull` | Los 3 |
| [D. Levantar todo](#d-levantar-todo) | Dentro de la VM | PC 1 primero, después PC 2 y 3 |
| [E. Verificar](#e-verificar-y-ensayar-la-demo) | Dentro de la VM y en el navegador | Los 3 |

**Qué corre cada PC**

| PC | Compose | Contenedores | Puertos | En el `.env` |
| --- | --- | --- | --- | --- |
| PC 1 (acceso, Salma) | `docker-compose.servidores.yml` **y** `docker-compose.app.yml` | `eventos-db`, `eventos-nginx`, `eventos-front`, `eventos-api1` | 80 balanceador, 5432 base, 8080 y 8081 front, 3000 api | `INSTANCIA=api1`, `PUERTO_WEB=8081` |
| PC 2 | `docker-compose.app.yml` | `eventos-front`, `eventos-api2` | 80 y 8080 front, 3000 api | `INSTANCIA=api2` (sin `PUERTO_WEB`) |
| PC 3 | `docker-compose.app.yml` | `eventos-front`, `eventos-api3` | 80 y 8080 front, 3000 api | `INSTANCIA=api3` (sin `PUERTO_WEB`) |

En las 3 PCs, `http://IP-de-la-PC` muestra la app: en la PC 1 entra por el balanceador, en la PC 2 y la PC 3 por el front de esa PC.

> Los comandos de Ubuntu se escriben en la **Terminal** (`Ctrl + Alt + T`). Para pegar en la terminal: `Ctrl + Shift + V`.
> Cuando un comando pide contraseña (`sudo`), es la del usuario de Ubuntu; mientras se escribe no se ve nada, es normal.

---

## A. En Windows

### A1. Tener el repo actualizado en VS Code

1. Abrir la carpeta del repo en VS Code.
2. Abrir la terminal de VS Code (`Ctrl + ñ` o menú **Terminal → New Terminal**).
3. Traer lo último de GitHub:
   ```
   git checkout main
   git pull
   ```
4. Verificar que estén los archivos de la demo: en la raíz `docker-compose.app.yml` y `docker-compose.servidores.yml`;
   `front-eventos/Dockerfile`, `api-eventos/Dockerfile` y `nginx/nginx.conf.template`. Si no están, alguien no los subió todavía.

### A2. Activar la virtualización

1. Abrir el **Administrador de tareas** (`Ctrl + Shift + Esc`) → pestaña **Rendimiento** → **CPU**.
2. Abajo a la derecha tiene que decir **Virtualización: Habilitado**.
3. Si dice *Deshabilitado*: reiniciar, entrar al BIOS/UEFI (según la marca: `F2`, `F10`, `Supr` o `Esc` al prender) y activar
   **Intel VT-x** / **Intel Virtualization Technology** o **AMD-V** / **SVM Mode**. Guardar y salir.

> Si en la PC está instalado **Docker Desktop** o WSL, VirtualBox igual funciona, pero más lento (aparece una tortuga verde abajo en la ventana de la VM).
> Para la demo alcanza; no hace falta desinstalar nada.

### A3. Descargar lo necesario

| Qué | De dónde | Notas |
| --- | --- | --- |
| VirtualBox | virtualbox.org → **Downloads** → *Windows hosts* | Instalar con todo por defecto (siguiente, siguiente). Si pide instalar drivers de red, aceptar |
| Ubuntu Desktop | ubuntu.com/download/desktop | La versión **LTS** más nueva. Es un archivo `.iso` de unos 6 GB |

### A4. Crear la máquina virtual

1. Abrir VirtualBox → **Nueva** (*New*).
2. **Nombre:** `ubuntu-so`. **Imagen ISO:** elegir el `.iso` descargado. VirtualBox detecta Ubuntu solo.
3. **Instalación desatendida** (*Unattended install*): dejarla activada y completar:
   - Usuario y contraseña (anotarlos; los tres pueden usar lo mismo, por ejemplo usuario `so`).
   - Marcar **Instalar Guest Additions** (*Guest Additions*). Sirve para copiar y pegar entre Windows y la VM, y para que la pantalla se adapte.
4. **Hardware:**
   - Memoria: **4096 MB** como mínimo (si la PC tiene 16 GB, poner 6144 u 8192).
   - Procesadores: **2** (o más).
5. **Disco duro:** crear uno nuevo de **30 GB** como mínimo.
6. **Terminar.** La VM arranca y Ubuntu se instala solo (tarda entre 15 y 30 minutos). No tocarla hasta que aparezca la pantalla de inicio de sesión.

### A5. Configurar la red en "Adaptador puente"

Es **lo más importante**: con la red por defecto (NAT) las VMs de las 3 PCs no se ven entre sí.

1. Apagar la VM (en Ubuntu: menú de arriba a la derecha → **Apagar**).
2. En VirtualBox, seleccionar la VM → **Configuración** → **Red** → **Adaptador 1**.
3. **Conectado a:** `Adaptador puente` (*Bridged Adapter*).
4. **Nombre:** la placa con la que la PC está conectada a internet (la de Wi-Fi si está por Wi-Fi, la Ethernet si está por cable).
5. **Aceptar** y volver a prender la VM.

### A6. Activar copiar y pegar

1. Con la VM prendida, menú de la ventana de VirtualBox: **Dispositivos** → **Portapapeles compartido** → **Bidireccional**.
2. Si no funciona, las Guest Additions no se instalaron: ver [B1](#b1-primer-arranque).

---

## B. En Ubuntu (instalación limpia)

Todo esto se hace **en las 3 VMs**, igual.

### B1. Primer arranque

1. Iniciar sesión con el usuario creado en A4.
2. Si aparece el asistente de bienvenida, avanzar con *Siguiente* / *Omitir* hasta el final.
3. Si aparece **Actualización de software**, dejar que instale y reiniciar.
4. Abrir la Terminal (`Ctrl + Alt + T`) y probar que el usuario puede usar `sudo`:
   ```
   sudo whoami
   ```
   Tiene que responder `root`. Si dice *"no está en el archivo sudoers"* (pasa a veces con la instalación desatendida):
   ```
   su -
   usermod -aG sudo NOMBRE_DE_USUARIO
   exit
   ```
   (la contraseña de `su` es la misma del usuario), y después cerrar sesión y volver a entrar.
5. **Solo si el copiar y pegar no anda** (A6; al pegar en Ubuntu aparece lo último copiado adentro de Ubuntu y no lo de Windows):
   instalar las Guest Additions desde los paquetes de Ubuntu (escribirlo a mano, todavía no se puede pegar):
   ```
   sudo apt install -y virtualbox-guest-x11
   ```
   Reiniciar la VM y volver a marcar **Dispositivos** → **Portapapeles compartido** → **Bidireccional**.

   Si `apt` no encuentra el paquete: menú de VirtualBox → **Dispositivos** → **Insertar imagen de CD de los complementos del invitado**, y en la terminal
   `sudo apt install -y build-essential bzip2` y `sudo sh /media/$USER/VBox*/VBoxLinuxAdditions.run`. Reiniciar.

### B2. Actualizar el sistema e instalar herramientas básicas

```
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl nano openssl
```

- `git`: para clonar el repo.
- `curl`: para descargar instaladores y probar la API.
- `nano`: editor de texto en la terminal (para el `.env`).

### B3. Instalar Docker Engine

Con el script oficial de Docker:

```
curl -fsSL https://get.docker.com -o instalar-docker.sh
sudo sh instalar-docker.sh
```

Para no tener que poner `sudo` delante de cada comando de Docker:

```
sudo usermod -aG docker $USER
```

**Reiniciar la VM** desde el menú de arriba a la derecha (botón de apagado → **Reiniciar…**). Sin eso el cambio no se aplica.
En Ubuntu 26.04 no viene `newgrp`, así que no hay atajo, y `sudo reboot` desde la terminal lo bloquea la sesión gráfica
(*"Operation inhibited"*); si se quiere hacer por terminal: `sudo systemctl reboot -i`.

Verificar:

```
docker --version
docker compose version
docker run --rm hello-world
```

El último tiene que imprimir **"Hello from Docker!"**. Si dice *permission denied*, faltó cerrar sesión.

Que Docker arranque solo cada vez que se prende la VM:

```
sudo systemctl enable docker
```

Docker Hub puede bajar muy lento. Usar el mirror de Google (copia de las imágenes de Docker Hub):

```
echo '{ "registry-mirrors": ["https://mirror.gcr.io"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

### B4. Instalar Claude Code

```
curl -fsSL https://claude.ai/install.sh | bash
```

Cerrar y volver a abrir la terminal, y escribir `claude`. La primera vez pide iniciar sesión: abre el navegador de la VM, se entra con la cuenta de Claude
y se vuelve a la terminal. Para salir de Claude: `/exit`.

> Claude Code se puede usar desde la carpeta del repo (`cd ~/backstage` y `claude`) para que ayude con cualquier paso de esta guía.

### B5. (Opcional) Instalar VS Code en Ubuntu

Para editar archivos con la misma herramienta que en Windows:

```
sudo snap install code --classic
```

Se abre con `code .` desde la carpeta del repo. Si no, todo se puede editar con `nano`.

### B6. Clonar el repo

```
cd ~
git clone https://github.com/urendadiego/Trabajo-Integrador-Intermaterias-LBZ.git backstage
cd backstage
ls
```

Tienen que aparecer `api-eventos`, `front-eventos`, `nginx`, `docker-compose.app.yml`, `docker-compose.servidores.yml`, etc.

El repo es público: clonar no pide usuario ni contraseña. En las VMs solo se hace `git pull`; los cambios se suben desde Windows.

### B7. Crear el `.env`

```
cp .env.example .env
nano .env
```

Cambiar:

| Variable | Qué poner |
| --- | --- |
| `POSTGRES_PASSWORD` | Una contraseña para la base. **La misma en las 3 PCs** |
| `JWT_SECRET` | Un texto largo. **El mismo en las 3 PCs** (si no, la sesión se corta al cambiar de réplica) |
| `INSTANCIA` | `api1` en la PC 1, `api2` en la PC 2, `api3` en la PC 3 |
| `PUERTO_WEB` | **Solo en la PC 1:** descomentar la línea (`PUERTO_WEB=8081`), porque el 80 lo usa el balanceador. En la PC 2 y la PC 3 dejarla comentada |
| `GMAIL_USUARIO`, `GMAIL_CLAVE_APP` | Opcional: solo si se quiere que lleguen los mails. Vacío funciona igual |

Las líneas `IP_PC…` dejarlas comentadas (con `#`): las IPs van en los compose (parte C).

El `JWT_SECRET` y la contraseña los genera **una sola persona** (PC 1) y se los pasa a los otros dos por privado (nunca en el repo):

```
openssl rand -hex 32
```

Guardar en `nano`: `Ctrl + O`, `Enter`, y salir con `Ctrl + X`.

### B8. Ver la IP de la VM

```
ip -4 a
```

Buscar la placa que **no** es `lo` ni `docker0` (suele llamarse `enp0s3`) y anotar el número de `inet`, por ejemplo `192.168.0.15`.

- Si empieza con **10.0.2.** la red está en NAT: volver a [A5](#a5-configurar-la-red-en-adaptador-puente).
- Las 3 VMs tienen que tener IPs **de la misma red** (por ejemplo, las tres `192.168.0.x`).

Probar que las VMs se ven entre sí, desde cada una hacia las otras:

```
ping -c 3 IP_DE_OTRA_VM
```

Si no hay respuesta y las tres están en el Wi-Fi de la facultad, probablemente la red aísla los dispositivos: conectar las 3 PCs al **hotspot de un celular** o a un router propio.

### B9. Firewall

En Ubuntu Desktop el firewall viene apagado. Verificar:

```
sudo ufw status
```

Si dice `Status: active`, abrir los puertos:

```
sudo ufw allow 80,8080,3000,5432/tcp
```

---

## C. Las IPs (una sola vez entre los 3)

Las IPs se escriben **en los compose** (como valor por defecto), así no hay que acordarse de ponerlas en el `.env` de cada PC.

1. Juntar las 3 IPs de B8: PC 1 (la de Salma), PC 2 y PC 3.
2. **Una sola persona**, en VS Code (en Windows), cambia los números en:
   - `docker-compose.app.yml`: `DB_HOST: ${IP_PC1:-…}` → la IP de la PC 1.
   - `docker-compose.servidores.yml`: `IP_PC1`, `IP_PC2` e `IP_PC3` → las tres IPs.

   Solo se cambia el número que está después de `:-`. Por ejemplo `${IP_PC1:-192.168.0.15}`.
3. Commit y push a `main`.
4. En **cada VM**:
   ```
   cd ~/backstage
   git pull
   ```

**Si un día cambian las IPs** (otra red, otro día): repetir esta parte, o pasarlas en el comando sin tocar los archivos:

```
IP_PC1=192.168.43.10 IP_PC2=192.168.43.11 IP_PC3=192.168.43.12 docker compose -f docker-compose.servidores.yml up -d
IP_PC1=192.168.43.10 docker compose -f docker-compose.app.yml up -d --build
```

---

## D. Levantar todo

### D1. PC 1 (acceso): base y nginx

```
cd ~/backstage
docker compose -f docker-compose.servidores.yml up -d
docker compose -f docker-compose.servidores.yml ps
```

Esperar a que `eventos-db` diga `healthy` (repetir el `ps` cada tanto). La primera vez Postgres corre los scripts de `api-eventos/database/`:

```
docker compose -f docker-compose.servidores.yml logs db
```

Tiene que terminar con `database system is ready to accept connections` y sin `ERROR`. Comprobar las tablas:

```
docker exec -it eventos-db psql -U postgres -d backstage -c "\dt"
```

Tienen que aparecer 16 tablas.

### D2. Las 3 PCs: front y back

En **cada VM** (la PC 1 también), después de que la base de la PC 1 esté `healthy`:

```
cd ~/backstage
docker compose -f docker-compose.app.yml up -d --build
docker compose -f docker-compose.app.yml ps
```

La primera vez tarda varios minutos: descarga las imágenes de Node, instala dependencias y compila el front.
Al final tienen que estar `eventos-front` y `eventos-api1` (o `api2` / `api3`) en `running`.

Probar en la misma VM:

```
curl http://localhost:3000/api/salud
curl -I http://localhost:8080
```

El primero responde algo como `{"ok":true,"instancia":"api2"}`; el segundo, `HTTP/1.1 200 OK`.

En la PC 2 y la PC 3 el front también queda en el puerto 80, con su propia api detrás:

```
curl http://localhost/api/salud
```

Tiene que responder con la `instancia` de esa PC (`api2` o `api3`).

---

## E. Verificar y ensayar la demo

### E1. Desde otra PC, que se vean los servicios

Desde la VM de la PC 1, hacia la PC 2 y la PC 3:

```
curl http://IP_PC2:3000/api/salud
curl -I http://IP_PC2:8080
```

### E1b. Entrar a cada PC por su IP

En el navegador, **`http://IP_PC1`**, **`http://IP_PC2`** y **`http://IP_PC3`** tienen que mostrar la app y dejar usarla (login, cartelera).

- `http://IP_PC1` es el balanceador: reparte entre las 3 PCs.
- `http://IP_PC2` y `http://IP_PC3` los atiende el nginx del front de esa PC, que le pasa `/api/` a la api de la misma PC.
  `http://IP_PC2/api/salud` responde siempre `api2`.

### E2. El balanceo

Desde cualquier VM:

```
for i in 1 2 3 4 5 6; do curl -s http://IP_PC1/api/salud; echo; done
```

Tiene que ir alternando `api1`, `api2`, `api3`.

En el navegador (de cualquier VM o de cualquier compu en la misma red): **`http://IP_PC1`**. Es la dirección que se le pasa al profesor.
Usar la app: login, cartelera, panel.

Ver a qué nodo mandó nginx cada pedido (en la PC 1):

```
docker compose -f docker-compose.servidores.yml logs -f nginx
```

(`Ctrl + C` para salir.)

### E3. Tolerancia a fallas

En la PC 2:

```
docker compose -f docker-compose.app.yml stop
```

Repetir el `for` de E2 y usar la app: sigue andando con `api1` y `api3`. Después volver a prender:

```
docker compose -f docker-compose.app.yml start
```

### E4. Lo que se muestra en la defensa

El guion completo está en la [sección 6 del plan](plan.md#6-guion-de-la-demo).

---

## Comandos de todos los días

| Para qué | Comando |
| --- | --- |
| Ver qué contenedores corren | `docker ps` |
| Traer cambios del repo | `cd ~/backstage && git pull` |
| Reconstruir después de un `git pull` con cambios de código | `docker compose -f docker-compose.app.yml up -d --build` |
| Apagar la app (sin borrar nada) | `docker compose -f docker-compose.app.yml down` |
| Apagar base y nginx (los datos quedan en el volumen) | `docker compose -f docker-compose.servidores.yml down` |
| Ver los errores de la API | `docker logs eventos-api1` (o `api2` / `api3`) |
| Recargar nginx después de cambiar IPs | `docker compose -f docker-compose.servidores.yml up -d --force-recreate nginx` |

> **Nunca** `docker compose … down -v`: la `-v` borra el volumen y con él todos los datos de la base.
> Solo se usa a propósito, para que los scripts SQL vuelvan a correr desde cero.

## Si algo falla

| Problema | Qué revisar |
| --- | --- |
| Al arrancar Ubuntu: `vmwgfx … unsupported hypervisor` | Es un aviso: esperar unos minutos. Si no avanza: apagar la VM → **Configuración → Pantalla**: memoria de video 128 MB, controlador `VBoxSVGA`, sin aceleración 3D. Si sigue, actualizar VirtualBox o usar Ubuntu 24.04 LTS |
| `permission denied` al usar `docker` | Faltó cerrar sesión después de B3 |
| La IP empieza con `10.0.2.` | La red está en NAT, no en puente (A5) |
| `ping` entre VMs no responde | Las 3 en la misma red; probar con el hotspot de un celular |
| La API responde pero da error de base | `DB_HOST` en `docker-compose.app.yml` no es la IP de la PC 1, o `POSTGRES_PASSWORD` distinto al de la PC 1 |
| Se corta la sesión al navegar | `JWT_SECRET` distinto en alguna PC |
| En la PC 1: `Bind for 0.0.0.0:80 failed: port is already allocated` al levantar la app | Falta `PUERTO_WEB=8081` en el `.env` de la PC 1 (B7) |
| `http://IP_PC1` da `502 Bad Gateway` | Ningún front o ninguna API responde: revisar `docker ps` en las 3 PCs y las IPs de `docker-compose.servidores.yml` |
| El build del front se corta o tarda muchísimo | Poca memoria en la VM: subirla a 6 GB (A4) |
| Las descargas (`docker pull`, `npm ci`) van a pocos KB/s | El adaptador puente sobre Wi-Fi a veces es muy lento. Pasar la red a **NAT** (**Dispositivos → Red → Configuración de red**, se puede con la VM prendida; después apagar y prender la conexión en Ubuntu), bajar todo con `docker pull postgres:17-alpine nginx:alpine` y `docker compose -f docker-compose.app.yml build`, y volver a **Adaptador puente** para levantar. Las imágenes quedan guardadas |
