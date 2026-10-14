# Backstage — Plan general del proyecto

Plataforma multitenant para **productoras de recitales y festivales**.
Este documento define el dominio, el DER, los perfiles de usuario, la API, el front y el orden de trabajo.
Es la referencia del grupo: si algo cambia, se cambia acá primero.
El dominio del negocio (actores, procesos, reglas) está en [comun/dominio.md](../comun/dominio.md), y el modelo de datos en [base-de-datos/der.md](../base-de-datos/der.md).

---

## 1. Perfiles de usuario

| Rol | Quién es | Qué hace |
| --- | --- | --- |
| **superadmin** | Nosotros, los dueños de la plataforma | Da de alta productoras y sus usuarios. Carga el **catálogo de lugares** (con escenarios y espacios) que pueden usar todas. Define el % de service charge. Ve todo, incluida la recaudación de la plataforma. |
| **empresa** | Personal de una productora (tenant) | Usa los lugares del catálogo o carga **los suyos**. Carga **sus artistas**. Arma eventos (jornadas, escenarios, line-up) y **maneja sus entradas**: tarifas por sector, ventas y control de acceso (los cupos salen de la capacidad del lugar). |
| **cliente** | Público final | Ve la cartelera pública de todas las productoras, compra entradas pagando el precio más el **service charge** (pago simulado) y ve "mis entradas". |

**Modelo de negocio.** Cada productora maneja sus propias entradas. Nosotros ponemos la pasarela de pago
(simulada, todo es ficticio) y cobramos un **service charge**: un porcentaje que el cliente paga sobre el precio de las entradas.
La productora cobra el subtotal y la plataforma se queda con el cargo.

Hay un solo rol `empresa`: no hay sub-roles de staff.

### Matriz de permisos

| Recurso | superadmin | empresa | cliente / visitante |
| --- | --- | --- | --- |
| Empresas | CRUD (incluye el % de service charge) | ver/editar **la propia** (el % no) | — |
| Usuarios | CRUD de todos | — | registrarse, editar su perfil |
| Lugares de la plataforma (+ escenarios, espacios) | CRUD | **solo lectura** (los usa en sus eventos) | ver (en el detalle del evento) |
| Lugares propios (+ escenarios, espacios) | ver | CRUD de los suyos | ver |
| Artistas | ver todos | CRUD de los suyos | ver |
| Eventos, jornadas, line-up, tarifas | ver todo y despublicar | CRUD de los suyos | ver solo los **publicados** |
| Compras / entradas | ver todo y la recaudación por service charge | ver las de sus eventos (subtotal) y validar entradas | comprar y ver las propias |

---

## 2. Patrón clave: lugares de la plataforma + lugares propios

En `lugares`:

- `id_empresa IS NULL` → es de la **plataforma**: lo carga el superadmin y lo pueden usar todas las productoras (los ~20 lugares predefinidos).
- `id_empresa = X` → es **propio** de la productora X: solo X lo ve, lo edita y lo usa. Las demás no lo ven.

`artistas` siempre tiene `id_empresa NOT NULL`: cada productora carga los suyos y no hay catálogo de la plataforma.
Si dos productoras traen al mismo artista, cada una tiene su propia fila.

Una productora solo puede usar en sus eventos lugares **de la plataforma o propios**, y artistas **propios**.
Esto se controla en el backend y con un trigger.

Los **escenarios** y **espacios** (platea, campo, VIP…) dependen del lugar. El lugar puede ser de la plataforma o propio,
y quien edita el lugar edita también sus escenarios, espacios y plano.

### 2.1 Capacidad y cupos: los define el lugar

- La capacidad la carga **quien registra el lugar**: nosotros para los de la plataforma, la productora para los propios.
- La capacidad se carga **por espacio** (sector). La capacidad total del lugar **no se guarda**: es la suma de sus espacios y se calcula en la vista `v_lugares`.
- Todo lugar tiene **al menos un espacio**. Si la productora no quiere sectorizar, el backend le crea un espacio "General" con la capacidad que indique.
- **La productora no define cupos.** Lo que se puede vender en un espacio, para un evento y una jornada, es:

  `capacidad del espacio − entradas válidas vendidas en ese espacio para esa jornada (las de abono cuentan en todas las jornadas)`

- Las tarifas solo fijan **precio**. Un espacio puede tener varias tarifas (Preventa, General), que comparten el mismo cupo.
  Un espacio sin tarifas en un evento no se vende en ese evento.

### 2.2 Plano del lugar (sectorización visual)

Cada lugar puede tener un **plano**: un lienzo donde se dibujan rectángulos o polígonos.
- **Espacios vendibles** (platea, campo, VIP): cada uno tiene forma, color y capacidad, y es lo que después tiene tarifa.
- **Escenarios**: se dibujan para que se vea dónde está cada uno. El line-up los usa.
- **Elementos de referencia** que no se venden: cabina de DJ, barras, baños, ingresos, mangrullo.

La forma se guarda como `geometria JSONB` (`{ "tipo": "rect", "x": 40, "y": 300, "w": 500, "h": 200 }` o `{ "tipo": "poligono", "puntos": [[x,y], ...] }`)
en coordenadas relativas al tamaño del lienzo (`lugares.plano_ancho` y `plano_alto`).

El plano es **opcional**: sin dibujo, los espacios y escenarios se cargan con un formulario común y todo funciona igual.
El dibujo suma dos cosas: en el panel, la productora sectoriza "dibujando"; en el checkout, el cliente **elige el sector haciendo clic en el mapa**,
que se pinta según la disponibilidad.

---

## 3. DER

El modelo de datos completo está en **[base-de-datos/der.md](../base-de-datos/der.md)** (entidades, cardinalidades, restricciones, reglas de borrado, normalización)
y en **[base-de-datos/backstage.dbml](../base-de-datos/backstage.dbml)** (para ver y exportar el diagrama en dbdiagram.io).

Resumen: 15 tablas en 4 grupos.
- **Plataforma:** empresas, usuarios
- **Lugares y plano:** lugares, escenarios, espacios, elementos_plano
- **Programación:** artistas, eventos, jornadas, evento_escenarios, presentaciones
- **Ventas y acceso:** tarifas, compras, entradas, ingresos

### 3.1 Multitenancy

Nos conectamos a Supabase con el usuario `postgres` por el pooler, así que **RLS no aplica**: el aislamiento lo hace el backend.
RLS sí está activado (sin políticas, en `09_seguridad.sql`), pero solo para cerrar la API pública de Supabase: no afecta a nuestra API.
- El JWT lleva `id_usuario`, `rol` e `id_empresa`.
- Todas las consultas del panel de empresa filtran con `WHERE id_empresa = req.usuario.id_empresa`. El `id_empresa` **nunca** se toma del body.
- Si una productora pide un recurso de otra, la respuesta es **404** (no 403), para no revelar que existe.

---

## 4. Base de datos (scripts SQL)

Carpeta `api-eventos/database/`, numerados y en orden de ejecución (Supabase → SQL Editor):

| Archivo | Contenido |
| --- | --- |
| `00_reset.sql` | `DROP` de todo, solo para desarrollo (**cuidado: la base es compartida**) |
| `01_extensiones.sql` | `pgcrypto` (para `gen_random_uuid`) y `btree_gist` (para los `EXCLUDE`) |
| `02_empresas_usuarios.sql` | `empresas` (ALTER sobre la tabla actual) y `usuarios` con un CHECK de rol/empresa |
| `03_lugares.sql` | `lugares`, `escenarios`, `espacios`, `elementos_plano` |
| `04_artistas.sql` | `artistas` |
| `05_eventos.sql` | `eventos`, `jornadas`, `evento_escenarios`, `presentaciones` |
| `06_ventas.sql` | `tarifas`, `compras`, `entradas`, `ingresos` |
| `07_triggers.sql` | Los 6 triggers del DER (lugar válido, jornada en rango, presentación en jornada, mínimo un espacio, compras solo de clientes, ingresos válidos) |
| `08_vistas.sql` | `v_cartelera` (eventos publicados con lugar y headliners), `v_lugares` (con la capacidad total calculada), `v_disponibilidad` (por evento, jornada y espacio: capacidad − vendidas), `v_asistencia` (entradas vs. ingresos por jornada), `v_recaudacion` (service charge por productora y mes) |
| `09_seguridad.sql` | Activa RLS (sin políticas) en todas las tablas y `security_invoker` en las vistas, para que la API pública de Supabase no exponga datos |
| `10_seed_plataforma.sql` | Superadmin y **20 lugares predefinidos** con escenarios, espacios con capacidad y, en algunos, el plano dibujado |
| `11_seed_demo.sql` | 3 productoras con usuarios, lugares y artistas propios, 1 festival de 3 días completo, 2 recitales y clientes con compras (con service charge) |

Las restricciones (CHECK, UNIQUE, FK compuestas, EXCLUDE, triggers) están listadas en [base-de-datos/der.md](../base-de-datos/der.md#4-restricciones-de-integridad).

Lugares predefinidos propuestos (mezcla de Córdoba y del resto del país): Estadio Mario Alberto Kempes, Orfeo Superdomo,
Quality Espacio, Plaza de la Música, Aeródromo Santa María de Punilla (Cosquín Rock), Estadio Monumental, La Bombonera,
Estadio Único de La Plata, Movistar Arena, Estadio Obras, Luna Park, Teatro Gran Rex, Teatro Ópera, Hipódromo de San Isidro,
Hipódromo de Palermo, Tecnópolis, Club Ciudad de Buenos Aires, Niceto Club, Estadio Gigante de Arroyito y Arena Maipú.

---

## 5. Backend (`api-eventos`)

### 5.1 Dependencias nuevas
`jsonwebtoken` (JWT), `bcryptjs` (hash de contraseñas) y `zod` (validar los body).

### 5.2 Estructura
```
src/
├── index.js
├── data/db.js
├── middlewares/
│   ├── autenticar.js        → valida el JWT y llena req.usuario
│   ├── permitir.js          → permitir("superadmin", "empresa")
│   ├── validar.js           → valida req.body con un schema de zod
│   └── manejarErrores.js    → traduce códigos de PG (23505 duplicado, 23503 FK, 23P01 superposición) a 400/409
├── routes/
│   ├── auth.routes.js
│   ├── public.routes.js     → cartelera, sin login
│   ├── admin/               → /api/admin/*   (superadmin)
│   ├── panel/               → /api/panel/*   (empresa, todo filtrado por su id_empresa)
│   └── cliente/             → /api/cliente/* (cliente)
├── controllers/   (igual separación por rol)
└── schemas/       (zod)
```

### 5.3 Endpoints

**Auth**
| Método | Ruta | Descripción |
| --- | --- | --- |
| POST | `/api/auth/login` | Devuelve JWT y datos del usuario |
| POST | `/api/auth/registro` | Alta de **cliente** (los otros roles los crea el superadmin) |
| GET | `/api/auth/yo` | Usuario actual |

**Público**
| GET | `/api/public/eventos` | Cartelera (publicados; filtros por ciudad, fecha, artista, género) |
| --- | --- | --- |
| GET | `/api/public/eventos/:id` | Detalle: jornadas, grilla (escenario × horario) y tarifas con disponibilidad |
| GET | `/api/public/artistas/:id` | Artista y sus próximas presentaciones |

**Superadmin** (`/api/admin`)
- `empresas` CRUD (lo que ya existe, se mueve acá).
- `usuarios` CRUD (crear usuarios de rol empresa con su productora).
- `lugares` CRUD del catálogo de la plataforma, con anidados `lugares/:id/escenarios` y `lugares/:id/espacios`,
  y `GET/PUT lugares/:id/plano` (guarda de una vez el lienzo, las formas de espacios y escenarios y los elementos, en una transacción).
- `artistas` GET de todos (solo lectura).
- `eventos` GET de todos y `PATCH /:id/estado` (despublicar o cancelar).
- `metricas` GET (productoras activas, eventos por estado, entradas vendidas, **recaudación por service charge** por productora y por mes).

**Empresa** (`/api/panel`)
- `GET/PUT /empresa`: datos de la propia productora.
- `lugares` → GET devuelve los de la plataforma y los propios (con un campo `origen`); POST/PUT/DELETE solo sobre los propios. Mismos anidados (escenarios, espacios, plano).
  Si se crea un lugar sin espacios, se genera "General" con la `capacidad` enviada.
- `artistas` → CRUD de los suyos.
- `eventos` CRUD, más:
  - `eventos/:id/jornadas` CRUD
  - `eventos/:id/escenarios` GET / PUT (reemplaza la lista habilitada)
  - `eventos/:id/presentaciones` CRUD (devuelve 409 si se superpone)
  - `eventos/:id/tarifas` CRUD (solo precio y vigencia, sin cupo)
  - `eventos/:id/disponibilidad` GET (capacidad, vendidas y libres por jornada y espacio)
  - `PATCH eventos/:id/estado` → publicar exige al menos 1 jornada, 1 presentación y 1 tarifa
  - `eventos/:id/ventas` GET con un resumen
- `POST /entradas/validar` → recibe un `codigo` y registra el ingreso de la entrada en la jornada (control de acceso).

**Cliente** (`/api/cliente`)
- `GET /compras/cotizar` → devuelve subtotal, service charge y total antes de pagar.
- `POST /compras` → `{ id_evento, items: [{ id_tarifa, cantidad }], medio_pago, tarjeta_ficticia }`. En una transacción: bloquea las tarifas del evento en los espacios involucrados,
  verifica que haya lugar en cada espacio y jornada (las de abono cuentan en todas),
  calcula `subtotal`, `cargo_servicio = subtotal × empresas.cargo_servicio_pct / 100` y `total`, **simula el pago**,
  y crea la compra y las entradas. Para poder probar el rechazo: una tarjeta terminada en `0000` se rechaza; cualquier otra se aprueba.
- `GET /compras` y `GET /entradas` (mis entradas, con código para mostrar como QR).
- `PUT /perfil`.

---

## 6. Frontend (`front-eventos`)

### 6.1 Dependencias nuevas
`dayjs` (ya viene con Ant Design), `qrcode.react` (para mostrar el QR de la entrada) y `konva` + `react-konva` (el editor y visor del plano:
rectángulos y polígonos que se arrastran, redimensionan y seleccionan).

### 6.2 Estructura
```
src/
├── context/AuthContext.jsx        → usuario, token (localStorage), login, logout
├── services/api.js                → axios con interceptor que agrega el Bearer y, si llega 401, hace logout
├── services/*.js                  → uno por recurso
├── routes/RutaProtegida.jsx       → <RutaProtegida roles={["empresa"]}>
├── layouts/
│   ├── PublicLayout.jsx           → navbar de cartelera
│   ├── AdminLayout.jsx            → Ant Layout + Sider
│   └── PanelLayout.jsx            → Ant Layout + Sider
├── pages/public/  pages/admin/  pages/panel/  pages/cliente/
└── components/                    → GrillaLineup, SelectorLugar, TablaTarifas,
                                     EditorPlano (dibujar), VisorPlano (solo ver / elegir sector), etc.
```

### 6.3 Pantallas

**Público y cliente** (`/`)
- `/` cartelera (Cards con filtros), `/eventos/:id` detalle (Tabs por jornada, grilla de line-up y tarifas, botón Comprar).
- `/login` y `/registro`, `/mis-entradas` (lista con QR).
- `/checkout/:idEvento`: elegir el sector en el **plano** (pintado según disponibilidad; si el lugar no tiene plano, una lista) y las cantidades, ver el resumen (subtotal + service charge = total), completar una tarjeta ficticia y ver el resultado.

**Superadmin** (`/admin`)
- Dashboard (métricas con `Statistic`, más la recaudación por service charge), Productoras (lo actual más el campo % de cargo), Usuarios.
- Lugares de la plataforma: tabla, y en el detalle Tabs con Datos, Escenarios, Espacios (con capacidad) y **Plano** (EditorPlano).
- Eventos (vista global con acciones de moderación).

**Empresa** (`/panel`)
- Dashboard (próximos eventos y ventas).
- Lugares: tabla con etiqueta *Plataforma* (solo lectura, el plano se ve con VisorPlano) o *Propio* (editable, con las mismas Tabs que el admin, plano incluido). Artistas: CRUD.
- **Evento en un asistente con `Steps`**:
  1. Datos (nombre, tipo, lugar, fechas)
  2. Jornadas (se generan solas a partir del rango de fechas y se pueden editar)
  3. Escenarios (checkboxes con los escenarios del lugar)
  4. **Line-up**: grilla con columnas = escenarios y filas = horario, una pestaña por jornada; se agrega una presentación con un modal (artista, inicio, fin, headliner). Si el backend devuelve 409, se muestra "se superpone con…"
  5. Tarifas: se elige el sector (en el plano o la lista), se ve su capacidad y se cargan los precios (por jornada o abono). No hay cupos.
  6. Revisar y publicar
- Ventas del evento y Validar entrada (un input donde se pega o escanea el código).

---

## 7. Fases y orden de trabajo

| Fase | Entregable | Depende de | Estado |
| --- | --- | --- | --- |
| **0. Acuerdo** | Este documento revisado por los 3; dudas cerradas | — | |
| **1. Base de datos** | Scripts 01–08 corriendo en Supabase, más los seeds 10 y 11 | 0 | Hecha: 01–11 corridos en Supabase el 2026-10-13 (con `09_seguridad.sql`) |
| **2. Base del backend** | Auth, middlewares, manejo de errores, mover `empresas` a `/api/admin` | 1 | Hecha |
| **3. Base del front** | AuthContext, api.js, layouts, RutaProtegida, login | 2 | Hecha |
| **4. Superadmin** | Productoras, usuarios, catálogo de lugares (escenarios, espacios) y artistas | 2, 3 | Productoras hecho |
| **5. Empresa** | Lugares y artistas propios, asistente de evento completo, publicar | 4 (usa el catálogo) | |
| **6. Público y cliente** | Cartelera, detalle con grilla, registro, compra, mis entradas | 5 (necesita eventos publicados) | Registro hecho |
| **7. Ventas y control** | Ventas por evento, validar entradas, métricas | 6 | |
| **7b. Plano** | EditorPlano (admin y empresa), VisorPlano en tarifas y checkout, planos del seed | 4 (es un agregado: todo funciona sin plano) | |
| **8. Cierre** | Deploy, README actualizado, DER exportado para Sistemas de Información | todo | |

### Reparto sugerido (después de hacer juntos las fases 1–3)
- **Persona A, superadmin:** fase 4 completa (backend y front), métricas de recaudación y **el plano (7b)**, porque nace en la pantalla de lugares.
- **Persona B, empresa:** fase 5 (la más pesada: artistas, asistente y grilla de line-up).
- **Persona C, público y cliente:** fase 6, checkout con service charge, pago simulado, mis entradas y validación.

Cada uno trabaja en ramas `feature/<tarea>` y abre un PR a `main`. Los cambios de esquema se avisan en el grupo **antes** de correrlos,
porque la base es una sola: cada cambio va como un archivo SQL nuevo (`12_agrega_x.sql`), nunca se edita en vivo.

---

## 8. Decisiones tomadas (2026-10-08)

1. **Roles:** superadmin (nosotros), empresa (productoras) y cliente (público que compra entradas).
2. **Lugares:** los de la plataforma los pueden usar todas las productoras. Los que carga cada productora son privados.
3. **Artistas:** los carga cada productora; no hay catálogo de la plataforma.
4. **Entradas:** cada productora las maneja (un solo rol `empresa`, sin sub-roles). La plataforma pone la pasarela de pago y cobra un **service charge**.
5. **Pago:** simulado, todo es ficticio.
6. **Cupos:** salen de la **capacidad de cada espacio del lugar**, que carga quien registra el lugar (nosotros o la productora). La productora solo pone precios por sector.
7. **Plano:** cada lugar puede tener un dibujo con sectores (platea, VIP, campo), escenarios y elementos de referencia (cabina de DJ, barras…). Es opcional y sirve para vender por sector.
