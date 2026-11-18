-- ============================================================================
-- DW · 02 · Crear la base del data warehouse
-- ----------------------------------------------------------------------------
-- Se corre conectado a cualquier base del servidor (por ejemplo, postgres).
-- En pgAdmin también se puede hacer a mano: clic derecho en Databases → Create → Database.
--
-- Es una base aparte de la operativa (backstage), en el MISMO servidor:
--   · los análisis no compiten con las ventas que entran en la operativa
--   · el DW tiene su propio diseño (estrella), pensado para consultar, no para registrar
-- ============================================================================

-- Si ya existe y se quiere empezar de cero, descomentar la línea de abajo
-- (WITH (FORCE) cierra las conexiones abiertas a esa base, por ejemplo la de pgAdmin):
-- DROP DATABASE IF EXISTS backstage_dw WITH (FORCE);

CREATE DATABASE backstage_dw ENCODING 'UTF8';
