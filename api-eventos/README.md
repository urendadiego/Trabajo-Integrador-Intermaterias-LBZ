# API Eventos

API del sistema de eventos **multitenant** (Node.js + Express + PostgreSQL).
Hoy tiene el login y, para el superadmin, el CRUD de productoras y de usuarios; la base ya tiene el modelo completo.

## Puesta en marcha

1. Clonar el repo e instalar dependencias:
   ```bash
   npm install
   ```
2. Crear el archivo `.env` (copiando `.env.example`) con la conexión a la base **compartida del grupo en Supabase**:
   ```
   PORT=3000
   FRONTEND_URL=http://localhost:5173
   DATABASE_URL=postgresql://postgres.xxxx:CONTRASEÑA@aws-1-us-west-2.pooler.supabase.com:5432/postgres
   JWT_SECRET=un-texto-largo-y-secreto
   ```
   `JWT_SECRET` es la clave con la que se firman las sesiones: cualquier texto largo. Sin ella la API no arranca.
   La `DATABASE_URL` se pide por privado al grupo (Supabase → Connect → URI → **Session pooler**).
   El `.env` **nunca** se sube a GitHub (ya está en `.gitignore`).
3. Levantar el servidor:
   ```bash
   npm run dev
   ```
   Queda en `http://localhost:3000`.

## Estructura

```
database/                          → scripts SQL numerados (ver "Base de datos")
src/index.js                       → crea el servidor y conecta todo
src/routes/                        → QUÉ rutas existen (admin/ = solo superadmin)
src/controllers/                   → QUÉ hace cada ruta
src/schemas/                       → validación de los body con zod
src/middlewares/autenticar.js      → valida el token y llena req.usuario { id_usuario, rol, id_empresa }
src/middlewares/permitir.js        → permitir("superadmin", ...) → 403 si el rol no está
src/middlewares/validar.js         → valida req.body o req.params con un schema
src/middlewares/manejarErrores.js  → traduce errores (zod, PostgreSQL) a 400 / 404 / 409
src/data/db.js                     → conexión a la base de datos
```

Los controllers no llevan try/catch: Express 5 manda los errores de las funciones async a `manejarErrores`.
Para cortar con un error se hace `throw new ErrorHttp(404, "Mensaje")`.

## Endpoints

Las rutas con candado necesitan el header `Authorization: Bearer <token>` (el token lo devuelve el login).

| Método | Ruta | Quién | Acción | Respuesta |
| ------ | ---- | ----- | ------ | --------- |
| POST | `/api/auth/login` | todos | `{ email, password }` → `{ token, usuario }` | 200 / 400 / 401 / 403 |
| POST | `/api/auth/registro` | todos | Alta de **cliente**. Manda un código por mail → `{ mensaje, email }` (sin token) | 201 / 400 / 409 / 503 |
| POST | `/api/auth/verificar` | todos | `{ email, codigo }` → verifica el email e inicia sesión → `{ token, usuario }` | 200 / 400 / 429 |
| POST | `/api/auth/reenviar-codigo` | todos | `{ email }` → manda un código nuevo (uno por minuto) | 200 / 429 / 503 |
| GET | `/api/auth/yo` | 🔒 cualquiera | Usuario de la sesión | 200 / 401 |
| GET | `/api/admin/empresas` | 🔒 superadmin | Listar productoras | 200 |
| GET | `/api/admin/empresas/:id` | 🔒 superadmin | Obtener una | 200 / 404 |
| POST | `/api/admin/empresas` | 🔒 superadmin | Crear | 201 / 400 / 409 |
| PUT | `/api/admin/empresas/:id` | 🔒 superadmin | Editar (solo los campos que vienen) | 200 / 400 / 404 / 409 |
| DELETE | `/api/admin/empresas/:id` | 🔒 superadmin | Borrar (solo si no tiene datos) | 204 / 404 / 409 |
| GET | `/api/admin/usuarios` | 🔒 superadmin | Listar. Filtros opcionales: `?rol=empresa&id_empresa=2&activo=true&buscar=texto` | 200 / 400 |
| GET | `/api/admin/usuarios/:id` | 🔒 superadmin | Obtener uno | 200 / 404 |
| POST | `/api/admin/usuarios` | 🔒 superadmin | Crear (cualquier rol) | 201 / 400 / 409 |
| PUT | `/api/admin/usuarios/:id` | 🔒 superadmin | Editar (solo los campos que vienen; el rol no se cambia) | 200 / 400 / 404 / 409 |
| DELETE | `/api/admin/usuarios/:id` | 🔒 superadmin | Borrar (solo si no tiene compras) | 204 / 400 / 404 / 409 |
| GET | `/api/salud` | todos | `{ ok, instancia }`, para ver qué réplica respondió | 200 |

- Errores: siempre `{ mensaje }`. Si son de validación, además `errores: [{ campo, mensaje }]`.
- Sin token o con token vencido → 401. Con un rol que no corresponde → 403.
- Un usuario dado de baja, o de una productora dada de baja, no puede iniciar sesión (403).
- Verificación del email: un cliente recién registrado no puede iniciar sesión hasta ingresar el código de 6 dígitos que le llega por mail.
  El login responde 403 con `motivo: "email_no_verificado"` (el front lo manda a `/verificar`).
  El código vence a los 15 minutos y con 5 intentos fallidos hay que pedir otro. Los usuarios que crea el superadmin no lo necesitan.
  - El mail sale de una cuenta de Gmail (`GMAIL_USUARIO` y `GMAIL_CLAVE_APP` en el `.env`, ver `.env.example`).
    Si no están configuradas, **el código aparece en la consola de la API**: sirve para probar sin Gmail.
  - Para sacar la contraseña de aplicación: cuenta de Google → Seguridad → activar la verificación en 2 pasos →
    "Contraseñas de aplicaciones" → crear una para "Backstage". Son 16 letras.
- Empresas: `nombre` y `cuit` (formato `30-12345678-9`) son obligatorios; `cargo_servicio_pct` va de 0 a 100 (por defecto 10).
  Un campo opcional enviado vacío (`""` o `null`) se borra. Un CUIT repetido responde 409.
- Una productora con usuarios, lugares, artistas o eventos no se borra (409): se da de baja con `activo: false`.
- Usuarios: `email`, `password` (mínimo 6), `nombre` y `rol` (`superadmin`, `empresa` o `cliente`) son obligatorios al crear;
  `apellido`, `dni` (solo números, 7 a 10) y `telefono` son opcionales. El email se guarda en minúscula y no se repite (409).
  - `id_empresa` es obligatorio si el rol es `empresa` y no va en los otros roles. La productora tiene que existir y estar activa.
  - Nunca se devuelve la contraseña. Si en el PUT viene `password`, se reemplaza.
  - Un cliente con compras no se borra (409): se da de baja con `activo: false` y ya no puede iniciar sesión.
  - El superadmin no puede darse de baja ni borrarse a sí mismo, y siempre tiene que quedar al menos uno activo (400).
- Cada respuesta trae el header `X-Instancia` (variable `INSTANCIA` o el nombre del equipo), para la demo de réplicas de Sistemas Operativos.

Ejemplo de body para POST `/api/admin/empresas`:
```json
{
  "nombre": "Mi Productora",
  "cuit": "30-71111111-1",
  "email": "contacto@miproductora.com",
  "telefono": "351-4000000",
  "direccion": "Calle 123, Córdoba",
  "cargo_servicio_pct": 10
}
```

## Base de datos

Los scripts de [database/](database/) se corren **en orden** en Supabase (SQL Editor → pegar → Run):

| Script | Qué hace |
| --- | --- |
| `00_reset.sql` | Borra todo. **Solo desarrollo, y avisando al grupo** (la base es compartida) |
| `01` a `06` | Extensiones y tablas. `02` no pisa la tabla `empresas` existente: le agrega las columnas nuevas |
| `07_triggers.sql` | Reglas que no entran en FK ni CHECK |
| `08_vistas.sql` | `v_lugares`, `v_disponibilidad`, `v_cartelera`, `v_asistencia`, `v_recaudacion` |
| `10_seed_plataforma.sql` | Superadmin y 20 lugares de la plataforma |
| `11_seed_demo.sql` | 3 productoras, usuarios, artistas, 1 festival, 2 recitales y compras |
| `12_verificacion_email.sql` | Columna `usuarios.email_verificado` (los que ya existen quedan verificados) y tabla `codigos_verificacion` |

Usuarios de prueba: `admin@backstage.com` / `admin123` (superadmin); `staff@eventosdelcentro.com`,
`staff@fiestasnorte.com`, `staff@produccionessur.com` (empresa) y `lucia.gomez@mail.com`, `martin.diaz@mail.com`,
`sofia.perez@mail.com` (cliente), todos con `demo123`.

Los cambios de esquema posteriores van en un script nuevo (`12_agrega_x.sql`), nunca editando uno ya corrido.
El modelo está explicado en [docs/base-de-datos/der.md](../docs/base-de-datos/der.md).

- CORS solo acepta pedidos desde `FRONTEND_URL` (el front de Vite).
- Todo el grupo comparte **una sola base** en Supabase (la tabla `empresas` ya está creada ahí).
  Si uno crea o borra una empresa, los demás lo ven.
- [src/data/db.js](src/data/db.js) se conecta usando `DATABASE_URL` (con SSL).
- Si la URL trae `?sslmode=require` al final, sacarlo (el SSL ya lo configura `db.js`).

## Deploy (opcional)

Si se sube a Vercel, se carga `DATABASE_URL` en las variables de entorno del proyecto
(conviene la URL del **Transaction pooler**, puerto 6543).
