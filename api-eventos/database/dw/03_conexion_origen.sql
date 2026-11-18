-- ============================================================================
-- DW · 03 · Conexión con la base operativa (postgres_fdw)
-- ----------------------------------------------------------------------------
-- Se corre en la base: backstage_dw
--
-- Dos bases del mismo servidor NO se ven entre sí: desde backstage_dw no se puede escribir
-- "SELECT * FROM backstage.compras". postgres_fdw (Foreign Data Wrapper) es la extensión de
-- Postgres que lo permite. Viene con la instalación de PostgreSQL, solo hay que activarla.
--
-- Se configura en tres pasos:
--   1. SERVER:       dónde está la otra base (host, puerto, nombre)
--   2. USER MAPPING: con qué usuario y contraseña entrar
--   3. IMPORT FOREIGN SCHEMA: crea en el esquema "origen" una "tabla foránea" por cada tabla
--      que se pida. No guardan datos: cada vez que se consultan, Postgres los va a buscar a
--      backstage. Por eso la carga es un INSERT ... SELECT ... FROM origen.<tabla>.
--
-- ANTES DE CORRERLO: reemplazar CAMBIAR_POR_TU_CLAVE por la contraseña del usuario postgres
-- (la misma con la que entrás a pgAdmin). El script ejecutar_todo.ps1 la reemplaza solo.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Se puede correr varias veces: borra lo anterior y lo vuelve a crear
DROP SCHEMA IF EXISTS origen CASCADE;
DROP SERVER IF EXISTS operativa CASCADE;

-- 1. Dónde está la base operativa.
--    fetch_size: cuántas filas trae por viaje (por defecto 100). Con 130.000 entradas, de a 100
--    son 1.300 viajes; de a 10.000, apenas 13. La carga pasa de ~35 s a pocos segundos.
CREATE SERVER operativa
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'backstage', fetch_size '10000');

-- 2. Con qué usuario se entra.
--    Tiene que ser postgres (superusuario): las tablas de la operativa tienen RLS activado sin
--    políticas (script 09_seguridad.sql, para Supabase). Un usuario común vería 0 filas;
--    el superusuario saltea RLS.
CREATE USER MAPPING FOR CURRENT_USER
    SERVER operativa
    OPTIONS (user 'postgres', password 'CAMBIAR_POR_TU_CLAVE');

-- 3. Traer solo las tablas que necesita el DW.
--    usuarios NO se importa: el DW no necesita emails, DNI ni contraseñas.
CREATE SCHEMA origen;
IMPORT FOREIGN SCHEMA public
    LIMIT TO (empresas, lugares, espacios, eventos, tarifas, compras, entradas, v_recaudacion)
    FROM SERVER operativa
    INTO origen;

-- Prueba: si esto devuelve filas, las dos bases ya se están comunicando
SELECT id_evento, nombre, fecha_inicio FROM origen.eventos ORDER BY id_evento LIMIT 5;
