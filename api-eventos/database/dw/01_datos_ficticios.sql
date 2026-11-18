-- Datos ficticios para la base operativa (base backstage, después de los scripts 01 a 12)
-- setseed hace que los datos generados sean siempre los mismos
SET max_parallel_workers_per_gather = 0;
SELECT setseed(0.42);

-- Productoras
INSERT INTO empresas (nombre, cuit, email, telefono, direccion, cargo_servicio_pct) VALUES
('Andes Live',          '30-71555123-4', 'contacto@andeslive.com',      '261-4201100', 'Av. San Martín 1500, Mendoza', 9),
('Litoral Shows',       '30-71666234-5', 'info@litoralshows.com',       '341-4302200', 'Bv. Oroño 900, Rosario',       11),
('Cumbre Producciones', '30-71777345-6', 'hola@cumbreproducciones.com', '11-43033300', 'Av. Corrientes 2000, CABA',    10),
('Bajo Cero Eventos',   '30-71888456-7', 'staff@bajocero.com',          '11-47044400', 'Thames 1800, CABA',            12);

-- Clientes (contraseña: demo123)
INSERT INTO usuarios (email, password_hash, nombre, apellido, dni, rol, email_verificado, fecha_creacion)
SELECT
    format('cliente%s@mail.com', lpad(i::text, 4, '0')),
    h.hash,
    (ARRAY['Lucía','Martín','Sofía','Juan','Valentina','Mateo','Camila','Tomás','Florencia','Lucas',
           'Agustina','Nicolás','Julieta','Santiago','Micaela','Facundo','Carolina','Joaquín','Brenda','Franco'])
        [1 + floor(random() * 20)::int],
    (ARRAY['González','Rodríguez','Gómez','Fernández','López','Díaz','Martínez','Pérez','Romero','Sosa',
           'Álvarez','Torres','Ruiz','Ramírez','Flores','Acosta','Benítez','Medina','Herrera','Suárez'])
        [1 + floor(random() * 20)::int],
    (20000000 + floor(random() * 25000000))::int::text,
    'cliente',
    TRUE,
    TIMESTAMP '2024-09-01' + random() * INTERVAL '90 days'
FROM generate_series(1, 1500) AS i
CROSS JOIN (SELECT crypt('demo123', gen_salt('bf', 10)) AS hash) AS h;

-- Recitales: uno cada 17 días en 10 lugares de la plataforma
CREATE TEMP TABLE tmp_eventos AS
WITH prod AS (
    SELECT array_agg(id_empresa ORDER BY id_empresa) AS ids FROM empresas
), lug AS (
    SELECT array_agg(id_lugar ORDER BY id_lugar) AS ids
    FROM lugares
    WHERE id_empresa IS NULL
      AND nombre IN ('Movistar Arena', 'Estadio Obras', 'Luna Park', 'Teatro Gran Rex', 'Teatro Ópera',
                     'Niceto Club', 'Quality Espacio', 'Orfeo Superdomo', 'Plaza de la Música', 'Arena Maipú')
), art AS (
    SELECT ARRAY['La Renga','Divididos','Babasónicos','Airbag','Ciro y los Persas','Las Pastillas del Abuelo',
                 'Miranda!','Wos','Nicki Nicole','Lali','Emilia','Los Caligaris','Bandalos Chinos','Dillom',
                 'Peces Raros','Usted Señálemelo','Hernán Cattáneo','El Mató a un Policía Motorizado'] AS nombres
)
SELECT
    i,
    nextval(pg_get_serial_sequence('eventos', 'id_evento'))::int   AS id_evento,
    nextval(pg_get_serial_sequence('jornadas', 'id_jornada'))::int AS id_jornada,
    prod.ids[1 + (i - 1) % array_length(prod.ids, 1)]  AS id_empresa,
    lug.ids[1 + (i * 7) % array_length(lug.ids, 1)]    AS id_lugar,
    art.nombres[1 + (i - 1) % array_length(art.nombres, 1)] AS artista,
    DATE '2025-03-07' + (i - 1) * 17                   AS fecha,
    LEAST(1, 0.35 + random() * 0.75)                   AS ocupacion,
    (25 + floor(random() * 14) * 5) * 1000             AS precio_base
FROM generate_series(1, 36) AS i, prod, lug, art;

-- Anticipación de compra según el tipo de lugar
ALTER TABLE tmp_eventos ADD COLUMN exponente NUMERIC;
UPDATE tmp_eventos te
SET exponente = CASE l.tipo WHEN 'teatro' THEN 1.2
                            WHEN 'predio' THEN 1.8
                            WHEN 'arena'  THEN 2.4
                            WHEN 'club'   THEN 4.0
                            ELSE 2.2 END
FROM lugares l
WHERE l.id_lugar = te.id_lugar;

-- Proporción de medios de pago de cada productora
CREATE TEMP TABLE tmp_medios AS
SELECT id_empresa, p_credito, p_credito + 0.15 + random() * 0.20 AS p_debito
FROM (SELECT id_empresa, 0.35 + random() * 0.35 AS p_credito FROM empresas ORDER BY id_empresa) AS x;

-- Eventos, jornadas y escenarios
INSERT INTO eventos (id_evento, id_empresa, id_lugar, nombre, descripcion, tipo,
                     fecha_inicio, fecha_fin, estado, fecha_creacion)
SELECT te.id_evento, te.id_empresa, te.id_lugar,
       te.artista || ' en ' || l.nombre, 'Recital generado para el data warehouse.', 'recital',
       te.fecha, te.fecha, 'finalizado', te.fecha - 120
FROM tmp_eventos te
JOIN lugares l ON l.id_lugar = te.id_lugar;

INSERT INTO jornadas (id_jornada, id_evento, fecha, hora_apertura)
SELECT id_jornada, id_evento, fecha, TIME '20:00' FROM tmp_eventos;

INSERT INTO evento_escenarios (id_evento, id_escenario, id_lugar)
SELECT te.id_evento, sc.id_escenario, sc.id_lugar
FROM tmp_eventos te
JOIN escenarios sc ON sc.id_lugar = te.id_lugar;

-- Tarifas: Preventa y General en cada sector
INSERT INTO tarifas (id_evento, id_lugar, id_espacio, id_jornada, nombre, precio, venta_desde, venta_hasta)
SELECT te.id_evento, te.id_lugar, es.id_espacio, te.id_jornada, t.nombre,
       round(te.precio_base * m.mult * t.factor / 1000) * 1000,
       te.fecha + t.desde, te.fecha + t.hasta
FROM tmp_eventos te
JOIN espacios es ON es.id_lugar = te.id_lugar
CROSS JOIN LATERAL (SELECT CASE WHEN es.nombre ILIKE '%VIP%' THEN 2
                                WHEN es.modalidad = 'sentado' THEN 1.25
                                ELSE 1 END AS mult) AS m
CROSS JOIN (VALUES
    ('Preventa', 0.8, INTERVAL '-90 days', INTERVAL '-30 days'),
    ('General',  1.0, INTERVAL '-30 days', INTERVAL '21 hours')
) AS t (nombre, factor, desde, hasta);

-- Compras pagadas hasta completar la ocupación de cada sector
CREATE TEMP TABLE tmp_compras AS
WITH sectores AS (
    SELECT te.id_evento, te.id_empresa, te.fecha, te.exponente, es.id_espacio,
           floor(es.capacidad * LEAST(1, te.ocupacion * (0.85 + random() * 0.2)))::int AS objetivo
    FROM tmp_eventos te
    JOIN espacios es ON es.id_lugar = te.id_lugar
), candidatas AS (
    SELECT s.id_evento, s.id_empresa, s.fecha, s.id_espacio, s.objetivo, g,
           (ARRAY[1, 2, 2, 2, 3, 4])[1 + floor(random() * 6)::int] AS cantidad,
           floor(90 * power(random(), s.exponente))::int           AS dias
    FROM sectores s
    CROSS JOIN LATERAL generate_series(1, ceil(s.objetivo / 1.5)::int) AS g
), acumuladas AS (
    SELECT c.*, SUM(cantidad) OVER (PARTITION BY id_evento, id_espacio ORDER BY g) AS acumulado
    FROM candidatas c
)
SELECT id_evento, id_empresa, fecha, id_espacio, cantidad, dias, 'pagada'::text AS estado
FROM acumuladas
WHERE acumulado <= objetivo;

-- Compras rechazadas y canceladas
INSERT INTO tmp_compras
SELECT id_evento, id_empresa, fecha, id_espacio, cantidad, dias,
       CASE WHEN random() < 0.8 THEN 'rechazada' ELSE 'cancelada' END
FROM tmp_compras
WHERE random() < 0.07;

-- Tarifa, cliente, fecha, medio de pago e importes de cada compra
CREATE TEMP TABLE tmp_compras_final AS
WITH clientes AS (
    SELECT array_agg(id_usuario ORDER BY id_usuario) AS ids FROM usuarios WHERE rol = 'cliente'
), base AS (
    SELECT tc.*,
           nextval(pg_get_serial_sequence('compras', 'id_compra'))::int AS id_compra,
           cl.ids[1 + floor(random() * array_length(cl.ids, 1))::int]    AS id_usuario,
           (tc.fecha - tc.dias) + INTERVAL '9 hours' + random() * INTERVAL '12 hours' AS fecha_compra,
           random() AS r_medio
    FROM tmp_compras tc, clientes cl
)
SELECT b.id_compra, b.id_usuario, b.id_evento, b.fecha_compra, b.cantidad, b.estado,
       t.id_tarifa, t.precio,
       t.precio * b.cantidad                                     AS subtotal,
       em.cargo_servicio_pct                                     AS pct,
       round(t.precio * b.cantidad * em.cargo_servicio_pct / 100, 2) AS cargo,
       CASE WHEN b.r_medio < md.p_credito THEN 'credito'
            WHEN b.r_medio < md.p_debito  THEN 'debito'
            ELSE 'transferencia' END                             AS medio_pago
FROM base b
JOIN tarifas t     ON t.id_evento = b.id_evento AND t.id_espacio = b.id_espacio
                  AND t.nombre = CASE WHEN b.dias >= 30 THEN 'Preventa' ELSE 'General' END
JOIN empresas em   ON em.id_empresa = b.id_empresa
JOIN tmp_medios md ON md.id_empresa = b.id_empresa;

-- Compras
INSERT INTO compras (id_compra, id_usuario, id_evento, fecha, subtotal, cargo_servicio_pct, cargo_servicio,
                     total, medio_pago, referencia_pago, estado)
SELECT id_compra, id_usuario, id_evento, fecha_compra, subtotal, pct, cargo,
       subtotal + cargo, medio_pago, 'SIM-' || upper(substr(md5(id_compra::text), 1, 10)), estado
FROM tmp_compras_final;

-- Entradas de las compras pagadas
INSERT INTO entradas (id_compra, id_evento, id_tarifa, precio_pagado)
SELECT f.id_compra, f.id_evento, f.id_tarifa, f.precio
FROM tmp_compras_final f
CROSS JOIN LATERAL generate_series(1, f.cantidad)
WHERE f.estado = 'pagada'
ORDER BY f.id_compra;

DROP TABLE tmp_eventos, tmp_medios, tmp_compras, tmp_compras_final;
ANALYZE;

-- Resumen
SELECT 'productoras' AS tabla, COUNT(*) AS filas FROM empresas
UNION ALL SELECT 'clientes',        COUNT(*) FROM usuarios WHERE rol = 'cliente'
UNION ALL SELECT 'eventos',         COUNT(*) FROM eventos
UNION ALL SELECT 'tarifas',         COUNT(*) FROM tarifas
UNION ALL SELECT 'compras',         COUNT(*) FROM compras
UNION ALL SELECT 'compras pagadas', COUNT(*) FROM compras WHERE estado = 'pagada'
UNION ALL SELECT 'entradas',        COUNT(*) FROM entradas;
