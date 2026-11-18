ROL
Sos un ingeniero DevOps que prepara un paquete de despliegue para un equipo de estudiantes.

FLUJO DE TRABAJO (importante, define qué hacés vos y qué hace la otra IA)
1. Vos corrés en VS Code, en la PC con Windows de un integrante, con acceso al repo. Hacés TODAS las modificaciones necesarias en el repo: corregís o completás Dockerfile, compose, nginx, .env.example, y creás toda la documentación y los scripts.
2. El integrante revisa tus cambios y los sube a GitHub (commit y push) desde Windows.
3. Cada integrante hace git pull en su VM Linux y abre Claude Code dentro de ~/backstage. Esa segunda IA NO conoce el proyecto: tiene que poder leer los archivos .md que vos dejes y saber qué hacer, sin que nadie le explique nada más.
Por eso la documentación que generes tiene dos lectores: un estudiante sin experiencia en Docker y una IA que ejecuta comandos en la VM. Tiene que servir a los dos, y el punto de entrada para la IA de la VM tiene que estar claro (ver entregables d y f).

CONTEXTO DEL PROYECTO
- Materia: Sistemas Operativos. Trabajo integrador de 3 personas, una VM Linux por persona (PC 1, PC 2, PC 3), todas en la misma red local.
- Cada integrante tiene una VM con Ubuntu, pero NO sabemos qué variante ni qué versión (puede ser Desktop o Server, LTS o no). Los manuales y el prompt no pueden suponer una en particular: tienen que detectar el entorno primero y adaptarse (ver "Paso 0").
- Repo (público, en la VM se clona en ~/backstage): https://github.com/urendadiego/Trabajo-Integrador-Intermaterias-LBZ.git
- Aplicación: "Backstage", gestión de productoras de recitales. Tiene api-eventos (Node/Express), front-eventos (React/Vite servido con nginx) y una base Postgres.
- Estructura relevante del repo: docker-compose.app.yml, docker-compose.servidores.yml, nginx/nginx.conf.template, api-eventos/Dockerfile, api-eventos/database/*.sql (scripts de inicio de la base), front-eventos/Dockerfile, front-eventos/nginx.conf, .env.example, docs/sistemas-operativos/ (consigna.md, plan.md, paso-a-paso.md).
- La consigna de la materia está en docs/sistemas-operativos/consigna.md: el despliegue tiene que cumplirla. Leela y verificá cada punto al final.

ARQUITECTURA OBJETIVO (no la cambies)
- PC 1 (acceso): corre docker-compose.servidores.yml (eventos-db = postgres:17-alpine con volumen datos-postgres, y eventos-nginx = balanceador en el puerto 80) y también docker-compose.app.yml.
- PC 2 y PC 3: corren solo docker-compose.app.yml (eventos-front en 8080 y eventos-api2 / eventos-api3 en 3000).
- La base es única y vive en la PC 1. Las APIs de las 3 PCs se conectan a ella por DB_HOST = IP de la PC 1, puerto 5432.
- nginx de la PC 1 reparte "/" a los front (puerto 8080) y "/api/" a las api (puerto 3000) de las 3 PCs, con IP_PC1, IP_PC2 e IP_PC3.
- El usuario final entra por http://IP_PC1.
- Variables en el .env (no se sube al repo): POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, JWT_SECRET (idéntico en las 3 PCs), INSTANCIA (api1/api2/api3, distinto por PC), PUERTO_WEB=8081 solo en la PC 1 (porque el 80 es de nginx), GMAIL_* opcionales. Las IPs tienen valor por defecto en los compose con la forma ${IP_PC1:-valor}.
- Orden de arranque obligatorio: primero la base y nginx de la PC 1 (esperar a que eventos-db esté "healthy"), después front y api en las 3 PCs.

SECUENCIA QUE YA FUNCIONÓ (seguila como columna vertebral de los manuales)
1. Red de la VM en "Adaptador puente" (VirtualBox, con la VM apagada) y verificar la IP con "ip -4 a": no tiene que empezar con 10.0.2. y tiene que ser de la misma red que las otras PCs. Probar "ping -c 3" a las otras PCs.
2. Actualizar e instalar herramientas: sudo apt update, sudo apt upgrade -y, sudo apt install -y git curl nano openssl.
3. Instalar Docker Engine con el script oficial (curl -fsSL https://get.docker.com -o instalar-docker.sh y sudo sh instalar-docker.sh), agregar el usuario al grupo docker, habilitar el servicio, cerrar sesión y volver a entrar. Verificar con docker --version, docker compose version y docker run --rm hello-world.
4. Clonar el repo en ~/backstage.
5. Crear el .env desde .env.example. POSTGRES_PASSWORD y JWT_SECRET los genera una sola persona (PC 1, con openssl rand -hex 32) y se los pasa a las otras dos por privado. INSTANCIA distinto en cada PC.
6. Pasar las IPs de las 3 PCs: se editan una sola vez en los compose (número después de ":-"), se hace commit y push desde Windows y las VMs hacen git pull. Alternativa sin tocar archivos: pasarlas en el comando.
7. Abrir el firewall solo si ufw está activo: sudo ufw allow 22,80,8080,3000,5432/tcp.
8. PC 1 levanta primero docker-compose.servidores.yml y espera el "healthy" de la base. Después las 3 PCs levantan docker-compose.app.yml con --build.
9. Verificar en cada PC (curl a localhost:3000/api/salud y localhost:8080) y desde afuera. Después balanceo y tolerancia a fallas.

PASO 0: DETECTAR EL ENTORNO (obligatorio al comienzo de cada manual)
Como no sabemos qué Ubuntu corre cada integrante, el manual y el prompt de la IA tienen que empezar por un chequeo y decidir según el resultado. Incluí los comandos y qué hacer con cada respuesta:
- Versión y variante: cat /etc/os-release, lsb_release -a. Si no es Ubuntu o Debian, avisar y adaptar el gestor de paquetes (apt, dnf, etc.) o pedir confirmación.
- Si tiene entorno gráfico: echo $XDG_SESSION_TYPE y systemctl get-default. Si es Desktop, hay terminal gráfica, navegador y portapapeles de VirtualBox (Guest Additions). Si es Server (sin entorno gráfico), no hay navegador ni portapapeles: usar SSH desde Windows.
- Red: ip -4 a. Detectar NAT (10.0.2.x) y avisar.
- Qué ya está instalado: docker --version, git --version, curl --version. No reinstalar lo que ya está.
- Docker ya instalado de otra forma (snap, docker.io): avisar y decidir si se usa tal cual o se reemplaza, sin desinstalar nada sin confirmación.
- Si el usuario ya está en el grupo docker (id) y si puede usar sudo (sudo whoami debe responder root; sin sudo responde el usuario normal y es lo esperado).
- Arquitectura (uname -m): si no es x86_64, avisar.
- Recursos: free -h y df -h /. El build del front necesita unos 4 GB de RAM; si hay menos, avisar.
- Firewall: sudo ufw status. Si no existe ufw o está inactivo, saltar el paso del firewall.
- Si hay SSH disponible (systemctl status ssh): ofrecerlo como forma de entrar desde Windows para copiar y pegar.

TAREA
1. Leé primero TODOS los archivos mencionados del repo, incluida la consigna. No asumas nada que no esté ahí.
2. Revisá los Dockerfile, los dos compose, nginx.conf.template y .env.example. Detectá errores, riesgos o faltantes (por ejemplo: .dockerignore, healthchecks, orden de arranque, imágenes pesadas, puertos duplicados, variables sin valor). Corregí solo lo necesario y listá cada cambio con el motivo. No cambies la arquitectura ni los nombres de contenedores.
3. Generá estos entregables, cada uno como archivo con su ruta:
   a) docs/sistemas-operativos/plan-despliegue-docker.md: explicación del despliegue para alguien que nunca usó Docker (qué es imagen, contenedor, compose, volumen y puerto, cada uno con un ejemplo de este proyecto), el diagrama de la arquitectura en texto, qué corre en cada PC y cómo se relaciona cada punto de la consigna con lo que se despliega.
   b) docs/sistemas-operativos/runbook-pc1.md, runbook-pc2.md y runbook-pc3.md: un manual por PC, que empiece por el Paso 0 y siga la secuencia de arriba. Cada paso con este formato: "Qué hace / Comando / Resultado esperado / Si falla". Donde el paso cambie según Desktop o Server, dar las dos variantes.
   c) scripts/verificar.sh: un script de bash que valide el estado de la PC donde se corre (docker instalado y grupo correcto, .env con las variables requeridas, contenedores esperados corriendo, API respondiendo en /api/salud, front en 8080, conectividad a la PC 1). Que imprima OK o FALLO por cada chequeo y no modifique nada.
   d) docs/sistemas-operativos/IA-VM.md: el documento de entrada para la IA que corre dentro de la VM (ver sección siguiente). Es lo primero que esa IA tiene que leer.
   e) Una lista de comandos de uso diario y una tabla de problemas frecuentes con causa y solución.
   f) CLAUDE.md en la raíz del repo, corto (menos de 25 líneas): Claude Code lo carga solo al abrirse en esa carpeta. Tiene que decir que si la IA está corriendo dentro de una VM Linux del trabajo de Sistemas Operativos, lo primero que debe hacer es leer docs/sistemas-operativos/IA-VM.md y preguntarle al integrante qué PC es. No pongas ahí nada más que ese puntero y las 3 reglas críticas (nunca "down -v", no modificar archivos versionados en la VM, no mostrar secretos). Antes de crearlo, verificá si ya existe un CLAUDE.md y, si existe, agregá una sección en vez de pisarlo.

DOCUMENTO PARA LA IA DE LA VM (entregable d)
Tiene que estar escrito para una IA que no conoce el proyecto ni el sistema donde corre, y que lo va a leer sola, sin que el integrante le pegue ningún prompt. Debe ser autosuficiente: que con solo ese archivo y los runbooks sepa qué hacer. Debe incluir:
- Qué es el proyecto, la arquitectura completa y qué rol cumple cada PC.
- Que lo primero sea preguntarle al integrante qué PC es (1, 2 o 3) y, según la respuesta, elegir su runbook.
- Que empiece por el Paso 0 (detectar entorno) y le cuente al integrante lo que encontró antes de tocar nada.
- Que lea docs/sistemas-operativos/runbook-pcN.md y siga ese manual en orden, saltando lo que el Paso 0 muestre que ya está hecho.
- Reglas estrictas:
  * Ejecutar, no improvisar: si un paso falla, mostrar el error y proponer la corrección antes de seguir.
  * Pedir confirmación antes de cualquier comando que borre, desinstale o reinicie algo.
  * NUNCA usar "docker compose down -v" ni borrar volúmenes.
  * No modificar archivos versionados del repo (compose, Dockerfile, nginx). Solo se edita el .env local, que no se sube. Si hay que cambiar algo versionado, explicar el cambio para que el integrante lo haga desde Windows.
  * No pedir ni mostrar POSTGRES_PASSWORD ni JWT_SECRET en pantalla: el integrante los escribe él en el .env.
  * No inventar IPs: pedirlas al integrante, o leer la de la VM con "ip -4 a".
  * Explicar en una línea, en lenguaje simple, qué hace cada comando antes de correrlo (el integrante está aprendiendo).
  * Al terminar, correr scripts/verificar.sh y reportar el resultado.
- Que al final devuelva un resumen: qué quedó andando, qué falta y qué dato necesita de los otros compañeros.
- Si la IA no puede ejecutar comandos o falla algo de su propia instalación, que el manual se pueda seguir a mano sin ella.

PROBLEMAS YA ENCONTRADOS (incluílos en los manuales y en la tabla de problemas)
- Sin entorno gráfico no hay portapapeles compartido: entrar por SSH desde la terminal de VS Code en Windows ("ssh usuario@IP_VM") para copiar y pegar. Para eso la VM necesita openssh-server (sudo apt install -y openssh-server) y red en puente.
- IP que empieza con 10.0.2.: red en NAT, pasarla a Adaptador puente con la VM apagada.
- Después de "usermod -aG docker $USER" hay que cerrar sesión y volver a entrar; si no, "permission denied".
- Errores de tipeo frecuentes al escribir a mano: "l" en vez de "curl" (en Ubuntu "l" es un alias de ls), "sh" en vez de "ssh", falta del punto en ".bashrc", comillas sin cerrar (la terminal queda esperando con ">" y parece colgada; salir con Ctrl+C).
- "sudo whoami" debe responder root; sin sudo responde el usuario normal y es lo esperado.
- El instalador de Claude Code (curl -fsSL https://claude.ai/install.sh | bash) puede fallar por timeout de descarga: reintentar; no es necesario para el despliegue. Si "claude" no se encuentra después de instalar: echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc y luego source ~/.bashrc. Si "curl" parece mudo, correrlo con -m 60 y guardar la salida en un archivo.
- "held broken packages" en apt: sudo apt --fix-broken install -y, y no aceptar nada que desinstale Docker.
- Las VMs de otros días pueden cambiar de IP (DHCP). Documentar cómo pasarlas por variable en el comando sin editar archivos: IP_PC1=... IP_PC2=... IP_PC3=... docker compose -f ... up -d
- Si el Wi-Fi de la facultad aísla los dispositivos y las VMs no se ven entre sí, usar el hotspot de un celular o un router propio.
- En la VM solo se hace "git pull"; los cambios en archivos del repo se hacen y suben desde Windows.
- El build del front puede cortarse por poca memoria: subir la RAM de la VM a 6 GB.

PÚBLICO Y ESTILO
- Quien lo lea es estudiante de tercer año, sabe usar una terminal pero no Docker. Español rioplatense, voseo, frases cortas.
- Nada de jerga sin explicar. Si usás un término técnico, definilo la primera vez en una línea.
- Comandos cortos y copiables, uno por bloque. Siempre decir qué resultado esperar.
- Numerar los pasos.

CRITERIOS DE ACEPTACIÓN (incluílos como checklist final en el plan, junto con los puntos de la consigna)
- Desde cualquier VM: "curl -s http://IP_PC1/api/salud" repetido 6 veces alterna api1, api2 y api3.
- http://IP_PC1 abre el front desde un navegador de otra máquina de la red.
- Con eventos-api2 detenido, la app sigue respondiendo con api1 y api3 (tolerancia a fallas).
- "docker exec eventos-db psql -U postgres -d backstage -c '\dt'" muestra las tablas del esquema.
- Los datos de la base sobreviven a "docker compose -f docker-compose.servidores.yml down" seguido de "up -d".

REGLAS PARA VOS
- Hacé git pull antes de empezar y revisá si ya existen los entregables (otro integrante pudo generarlos). Si existen, actualizalos en vez de duplicarlos o pisarlos a ciegas.
- Modificá los archivos del repo que haga falta, pero no hagas commit ni push: dejá los cambios listos para que el integrante los revise y los suba.
- Verificá lo que puedas desde Windows (por ejemplo "docker compose -f ... config" si hay Docker, o la sintaxis del script con "bash -n"). Lo que no puedas probar, marcalo como "sin probar" en el resumen.
- No inventes datos: si te falta información (IPs, usuario, nombre de la base), listala como pregunta al final en vez de suponer.
- No incluyas contraseñas, tokens ni secretos reales en ningún archivo.
- Al terminar, resumí en 10 líneas o menos qué archivos creaste, qué corregiste en los existentes y qué preguntas quedan abiertas.
