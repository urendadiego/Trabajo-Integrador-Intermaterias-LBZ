-- Consultas del data warehouse (base backstage_dw)

-- Pregunta 1: ¿Cuánto recauda cada productora por mes y cuánto cobra la plataforma en cargo por servicio?
SELECT
    CASE WHEN GROUPING(p.nombre) = 1 THEN 'TOTAL GENERAL' ELSE p.nombre END AS productora,
    CASE WHEN GROUPING(f.anio_mes) = 1 AND GROUPING(p.nombre) = 0 THEN 'Total'
         ELSE f.anio_mes END                                              AS mes,
    SUM(v.cantidad)                         AS entradas,
    SUM(v.precio_pagado)                    AS recaudacion_productora,
    SUM(v.cargo_servicio)                   AS cargo_plataforma,
    SUM(v.precio_pagado + v.cargo_servicio) AS total_cobrado
FROM fact_ventas v
JOIN dim_productora p ON p.sk_productora = v.sk_productora
JOIN dim_fecha      f ON f.sk_fecha      = v.sk_fecha
GROUP BY ROLLUP (p.nombre, f.anio_mes)
ORDER BY GROUPING(p.nombre), p.nombre, GROUPING(f.anio_mes), f.anio_mes;


-- Pregunta 2a: ¿Qué sectores venden más en cada evento y qué porcentaje de su capacidad vendieron?
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


-- Pregunta 2b: ¿Qué tarifas venden más?
SELECT t.nombre                                                   AS tarifa,
       SUM(v.cantidad)                                            AS entradas,
       round(100.0 * SUM(v.cantidad) / SUM(SUM(v.cantidad)) OVER (), 1) AS pct_entradas,
       SUM(v.precio_pagado)                                       AS recaudacion,
       round(AVG(v.precio_pagado), 2)                             AS precio_promedio
FROM fact_ventas v
JOIN dim_tarifa t ON t.sk_tarifa = v.sk_tarifa
GROUP BY t.nombre
ORDER BY entradas DESC;


-- Pregunta 3a: ¿Con cuánta anticipación compra la gente?
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


-- Pregunta 3b: ¿Cambia la anticipación según el tipo de lugar?
SELECT l.tipo                                  AS tipo_lugar,
       SUM(v.cantidad)                         AS entradas,
       round(AVG(v.dias_anticipacion), 1)      AS dias_promedio,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY v.dias_anticipacion) AS dias_mediana
FROM fact_ventas v
JOIN dim_lugar l ON l.sk_lugar = v.sk_lugar
GROUP BY l.tipo
ORDER BY dias_promedio DESC;


-- Pregunta 4a: ¿Qué medios de pago se usan en cada productora? (se cuentan compras, no entradas)
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


-- Pregunta 4b: ¿Qué medios de pago se usan según el tipo de lugar?
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


-- Pregunta 1 hecha en la base operativa, para comparar (correr en backstage)
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
