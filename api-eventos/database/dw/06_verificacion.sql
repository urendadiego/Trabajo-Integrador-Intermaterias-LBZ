-- ============================================================================
-- DW · 06 · Verificación de la carga
-- ----------------------------------------------------------------------------
-- Se corre en la base: backstage_dw   (después de CALL cargar_dw();)
--
-- Idea: contar y sumar lo mismo en los dos lados. Si el DW está bien cargado,
-- las diferencias tienen que dar 0. Del lado de la operativa se lee con origen.*
-- (postgres_fdw), así que todo se compara en una sola consulta.
-- ============================================================================

-- ─── 1. Totales generales ───────────────────────────────────────────────────
WITH dw AS (
    SELECT COUNT(*)                  AS entradas,
           COUNT(DISTINCT id_compra) AS compras,
           SUM(precio_pagado)        AS recaudacion,
           SUM(cargo_servicio)       AS cargo_servicio
    FROM fact_ventas
), operativa AS (
    SELECT (SELECT COUNT(*) FROM origen.entradas e
              JOIN origen.compras c ON c.id_compra = e.id_compra
             WHERE c.estado = 'pagada')                             AS entradas,
           COUNT(*)                                                 AS compras,
           SUM(subtotal)                                            AS recaudacion,
           SUM(cargo_servicio)                                      AS cargo_servicio
    FROM origen.compras
    WHERE estado = 'pagada'
)
SELECT 'Entradas vendidas' AS control, o.entradas::numeric AS operativa, d.entradas::numeric AS dw,
       o.entradas - d.entradas AS diferencia FROM dw d, operativa o
UNION ALL
SELECT 'Compras pagadas', o.compras, d.compras, o.compras - d.compras FROM dw d, operativa o
UNION ALL
SELECT 'Recaudación productoras ($)', o.recaudacion, d.recaudacion, o.recaudacion - d.recaudacion FROM dw d, operativa o
UNION ALL
SELECT 'Cargo por servicio ($)', o.cargo_servicio, d.cargo_servicio, o.cargo_servicio - d.cargo_servicio FROM dw d, operativa o;

-- ─── 2. Por productora, contra la vista v_recaudacion de la operativa ───────
-- v_recaudacion es la vista que usa el panel de la app: si coincide, el DW
-- dice lo mismo que la aplicación.
WITH operativa AS (
    SELECT productora, SUM(subtotal_productora) AS recaudacion, SUM(service_charge) AS cargo
    FROM origen.v_recaudacion
    GROUP BY productora
), dw AS (
    SELECT p.nombre AS productora, SUM(v.precio_pagado) AS recaudacion, SUM(v.cargo_servicio) AS cargo
    FROM fact_ventas v
    JOIN dim_productora p ON p.sk_productora = v.sk_productora
    GROUP BY p.nombre
)
SELECT COALESCE(o.productora, d.productora) AS productora,
       o.recaudacion                        AS operativa,
       d.recaudacion                        AS dw,
       COALESCE(o.recaudacion, 0) - COALESCE(d.recaudacion, 0) AS dif_recaudacion,
       COALESCE(o.cargo, 0)       - COALESCE(d.cargo, 0)       AS dif_cargo
FROM operativa o
FULL JOIN dw d ON d.productora = o.productora
ORDER BY productora;

-- ─── 3. Ninguna venta quedó afuera por falta de dimensión ───────────────────
-- Si algún JOIN del procedimiento no encontrara su dimensión, esa entrada no se cargaría
-- y el control 1 daría distinto. Este control lo confirma por evento.
SELECT COUNT(*) AS eventos_con_diferencia
FROM (
    SELECT e.id_evento, COUNT(*) AS entradas
    FROM origen.entradas e
    JOIN origen.compras c ON c.id_compra = e.id_compra
    WHERE c.estado = 'pagada'
    GROUP BY e.id_evento
) o
FULL JOIN (
    SELECT de.id_evento, COUNT(*) AS entradas
    FROM fact_ventas v
    JOIN dim_evento de ON de.sk_evento = v.sk_evento
    GROUP BY de.id_evento
) d ON d.id_evento = o.id_evento
WHERE o.entradas IS DISTINCT FROM d.entradas;

-- ─── 4. Historial de cargas ─────────────────────────────────────────────────
SELECT * FROM carga_log ORDER BY id_carga;
