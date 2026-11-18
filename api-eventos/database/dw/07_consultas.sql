-- ============================================================================
-- DW · 07 · Consultas: las preguntas que responde el data warehouse
-- ----------------------------------------------------------------------------
-- Se corre en la base: backstage_dw
-- En pgAdmin: seleccionar una consulta con el mouse y apretar F5 para correr solo esa.
--
-- Todas tienen la misma forma (es la ventaja del modelo estrella):
--   FROM fact_ventas
--   JOIN las dimensiones por las que se quiere mirar
--   GROUP BY los atributos de esas dimensiones
--   SUM / COUNT de las medidas
-- ============================================================================


-- ─── Pregunta 1 ─────────────────────────────────────────────────────────────
-- ¿Cuánto recauda cada productora por mes, y cuánto cobra la plataforma en cargo por servicio?
-- Mes = mes de la COMPRA (cuándo entra la plata), no del evento.
-- ROLLUP agrega una fila de total por productora y una de total general.
SELECT
    CASE WHEN GROUPING(p.nombre) = 1 THEN '— TOTAL GENERAL —' ELSE p.nombre END   AS productora,
    CASE WHEN GROUPING(f.anio_mes) = 1 AND GROUPING(p.nombre) = 0 THEN 'Total'
         ELSE f.anio_mes END                                                     AS mes,
    SUM(v.cantidad)                         AS entradas,
    SUM(v.precio_pagado)                    AS recaudacion_productora,
    SUM(v.cargo_servicio)                   AS cargo_plataforma,
    SUM(v.precio_pagado + v.cargo_servicio) AS total_cobrado
FROM fact_ventas v
JOIN dim_productora p ON p.sk_productora = v.sk_productora
JOIN dim_fecha      f ON f.sk_fecha      = v.sk_fecha
GROUP BY ROLLUP (p.nombre, f.anio_mes)
ORDER BY GROUPING(p.nombre), p.nombre, GROUPING(f.anio_mes), f.anio_mes;


-- ─── Pregunta 2a ────────────────────────────────────────────────────────────
-- ¿Qué sectores venden más en cada evento? ¿Qué porcentaje de su capacidad vendieron?
-- RANK() numera los sectores dentro de cada evento, del que más vendió al que menos.
SELECT e.fecha_inicio                       AS fecha,
       e.nombre                             AS evento,
       s.nombre                             AS sector,
       SUM(v.cantidad)                      AS entradas,
       s.capacidad,
       round(100.0 * SUM(v.cantidad) / s.capacidad, 1) AS pct_vendido,
       SUM(v.precio_pagado)                 AS recaudacion,
       RANK() OVER (PARTITION BY e.sk_evento ORDER BY SUM(v.cantidad) DESC) AS puesto
FROM fact_ventas v
JOIN dim_evento e ON e.sk_evento = v.sk_evento
JOIN dim_sector s ON s.sk_sector = v.sk_sector
GROUP BY e.sk_evento, e.fecha_inicio, e.nombre, s.nombre, s.capacidad
ORDER BY e.fecha_inicio, puesto;


-- ─── Pregunta 2b ────────────────────────────────────────────────────────────
-- ¿Qué tarifas venden más? (Preventa contra General, en todo el período)
SELECT t.nombre                                                   AS tarifa,
       SUM(v.cantidad)                                            AS entradas,
       round(100.0 * SUM(v.cantidad) / SUM(SUM(v.cantidad)) OVER (), 1) AS pct_entradas,
       SUM(v.precio_pagado)                                       AS recaudacion,
       round(AVG(v.precio_pagado), 2)                             AS precio_promedio
FROM fact_ventas v
JOIN dim_tarifa t ON t.sk_tarifa = v.sk_tarifa
GROUP BY t.nombre
ORDER BY entradas DESC;


-- ─── Pregunta 3a ────────────────────────────────────────────────────────────
-- ¿Con cuánta anticipación compra la gente? (curva de venta)
-- dias_anticipacion es una medida que calculó la carga: en la operativa no existe.
SELECT CASE WHEN v.dias_anticipacion = 0  THEN '1. El mismo día'
            WHEN v.dias_anticipacion <= 7  THEN '2. De 1 a 7 días antes'
            WHEN v.dias_anticipacion <= 30 THEN '3. De 8 a 30 días antes'
            WHEN v.dias_anticipacion <= 60 THEN '4. De 31 a 60 días antes'
            ELSE '5. Más de 60 días antes' END                         AS anticipacion,
       SUM(v.cantidad)                                                  AS entradas,
       round(100.0 * SUM(v.cantidad) / SUM(SUM(v.cantidad)) OVER (), 1) AS pct_entradas
FROM fact_ventas v
GROUP BY 1
ORDER BY 1;


-- ─── Pregunta 3b ────────────────────────────────────────────────────────────
-- ¿Cambia la anticipación según el tipo de lugar?
SELECT l.tipo                                  AS tipo_lugar,
       SUM(v.cantidad)                         AS entradas,
       round(AVG(v.dias_anticipacion), 1)      AS dias_promedio,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY v.dias_anticipacion) AS dias_mediana
FROM fact_ventas v
JOIN dim_lugar l ON l.sk_lugar = v.sk_lugar
GROUP BY l.tipo
ORDER BY dias_promedio DESC;


-- ─── Pregunta 4a ────────────────────────────────────────────────────────────
-- ¿Qué medios de pago se usan en cada productora?
-- Se cuentan COMPRAS, no entradas: una compra de 4 entradas es un solo pago.
-- Como el grano es la entrada, se cuenta con COUNT(DISTINCT id_compra).
SELECT p.nombre                                                       AS productora,
       m.nombre                                                       AS medio_pago,
       COUNT(DISTINCT v.id_compra)                                    AS compras,
       round(100.0 * COUNT(DISTINCT v.id_compra)
             / SUM(COUNT(DISTINCT v.id_compra)) OVER (PARTITION BY p.nombre), 1) AS pct_compras,
       SUM(v.precio_pagado + v.cargo_servicio)                        AS monto_cobrado
FROM fact_ventas v
JOIN dim_productora p ON p.sk_productora = v.sk_productora
JOIN dim_medio_pago m ON m.sk_medio_pago = v.sk_medio_pago
GROUP BY p.nombre, m.nombre
ORDER BY p.nombre, compras DESC;


-- ─── Pregunta 4b ────────────────────────────────────────────────────────────
-- Medios de pago por tipo de lugar, en columnas (FILTER arma una columna por medio)
SELECT l.tipo                                                                   AS tipo_lugar,
       COUNT(DISTINCT v.id_compra)                                              AS compras,
       COUNT(DISTINCT v.id_compra) FILTER (WHERE m.codigo = 'credito')          AS credito,
       COUNT(DISTINCT v.id_compra) FILTER (WHERE m.codigo = 'debito')           AS debito,
       COUNT(DISTINCT v.id_compra) FILTER (WHERE m.codigo = 'transferencia')    AS transferencia
FROM fact_ventas v
JOIN dim_lugar      l ON l.sk_lugar      = v.sk_lugar
JOIN dim_medio_pago m ON m.sk_medio_pago = v.sk_medio_pago
GROUP BY l.tipo
ORDER BY compras DESC;


-- ============================================================================
-- Para la defensa: la pregunta 1 hecha directo en la base OPERATIVA
-- ----------------------------------------------------------------------------
-- Correr en la base backstage. Hay que saber que el cargo está en compras, que la
-- productora se llega por eventos → empresas, y acordarse de filtrar las pagadas.
-- En el DW eso ya lo resolvió la carga: la consulta solo agrupa.
-- ============================================================================
-- SELECT em.nombre AS productora,
--        to_char(c.fecha, 'YYYY-MM') AS mes,
--        COUNT(e.id_entrada)         AS entradas,
--        SUM(e.precio_pagado)        AS recaudacion_productora
-- FROM compras c
-- JOIN entradas e  ON e.id_compra   = c.id_compra
-- JOIN eventos  ev ON ev.id_evento  = c.id_evento
-- JOIN empresas em ON em.id_empresa = ev.id_empresa
-- WHERE c.estado = 'pagada'
-- GROUP BY em.nombre, to_char(c.fecha, 'YYYY-MM')
-- ORDER BY 1, 2;
