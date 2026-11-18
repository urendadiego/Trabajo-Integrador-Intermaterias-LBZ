-- Conexión con la base operativa (correr en backstage_dw)
-- Reemplazar CAMBIAR_POR_TU_CLAVE por la contraseña del usuario postgres
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SCHEMA IF EXISTS origen CASCADE;
DROP SERVER IF EXISTS operativa CASCADE;

-- Servidor de la base operativa
CREATE SERVER operativa
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'backstage', fetch_size '10000');

-- Usuario con el que se entra
CREATE USER MAPPING FOR CURRENT_USER
    SERVER operativa
    OPTIONS (user 'postgres', password 'CAMBIAR_POR_TU_CLAVE');

-- Tablas de la operativa que usa el DW
CREATE SCHEMA origen;
IMPORT FOREIGN SCHEMA public
    LIMIT TO (empresas, lugares, espacios, eventos, tarifas, compras, entradas, v_recaudacion)
    FROM SERVER operativa
    INTO origen;

-- Prueba de la conexión
SELECT id_evento, nombre, fecha_inicio FROM origen.eventos ORDER BY id_evento LIMIT 5;
