-- ============================================================================
-- DW · 05 · Procedimiento de carga (ETL)
-- ----------------------------------------------------------------------------
-- Se corre en la base: backstage_dw      ·   Uso:  CALL cargar_dw();
--
-- ETL = Extract (leer de la operativa), Transform (calcular, filtrar), Load (insertar en el DW).
--
-- Tipo de carga: RECARGA COMPLETA. Vacía el DW y lo vuelve a llenar desde la operativa.
--   · Se puede correr las veces que haga falta y siempre da el mismo resultado (no duplica).
--   · Con nuestro volumen tarda segundos. Con millones de filas convendría una carga
--     incremental (traer solo lo nuevo desde la última carga).
--
-- Orden: PRIMERO las dimensiones, DESPUÉS los hechos.
--   fact_ventas tiene claves foráneas a las dimensiones y necesita sus sk_ ya creadas.
--
-- Todo el CALL es una sola transacción: si algo falla, no queda nada a medias
-- (el DW queda como estaba antes).
--
-- Claves foráneas e índices de fact_ventas: se quitan antes de cargar y se recrean al final.
--   Con las claves puestas, Postgres controla cada venta una por una (130.000 filas × 7 claves):
--   la carga tardaba ~37 s. Al recrearlas, valida todas las filas juntas en una pasada: ~8 s.
--   La integridad se controla igual: si una venta apuntara a una dimensión inexistente,
--   el ADD CONSTRAINT fallaría y se desharía toda la carga.
--
-- Transformaciones que hace (son las que justifican el DW):
--   · Solo pasan las compras PAGADAS: las rechazadas y canceladas no son ventas.
--   · El cargo por servicio está en la compra; se reparte entre sus entradas.
--   · Se calcula dias_anticipacion (no existe en la operativa).
--   · Los ids de la operativa se cambian por las claves sustitutas del DW.
-- ============================================================================

CREATE OR REPLACE PROCEDURE cargar_dw()
LANGUAGE plpgsql
AS $$
DECLARE
    v_inicio   TIMESTAMP := clock_timestamp();
    v_fechas   INT;
    v_eventos  INT;
    v_hechos   INT;
BEGIN
    -- ─── 0. Preparar y vaciar ───────────────────────────────────────────────
    -- Quitar claves foráneas e índices de la tabla de hechos (se recrean en el paso 3)
    ALTER TABLE fact_ventas
        DROP CONSTRAINT IF EXISTS fact_ventas_fecha_fk,
        DROP CONSTRAINT IF EXISTS fact_ventas_productora_fk,
        DROP CONSTRAINT IF EXISTS fact_ventas_lugar_fk,
        DROP CONSTRAINT IF EXISTS fact_ventas_evento_fk,
        DROP CONSTRAINT IF EXISTS fact_ventas_sector_fk,
        DROP CONSTRAINT IF EXISTS fact_ventas_tarifa_fk,
        DROP CONSTRAINT IF EXISTS fact_ventas_medio_pago_fk;
    DROP INDEX IF EXISTS fact_ventas_fecha_idx, fact_ventas_productora_idx, fact_ventas_lugar_idx,
                         fact_ventas_evento_idx, fact_ventas_sector_idx, fact_ventas_tarifa_idx,
                         fact_ventas_medio_idx;

    -- RESTART IDENTITY reinicia los SERIAL: las sk_ vuelven a empezar en 1
    TRUNCATE fact_ventas, dim_fecha, dim_productora, dim_lugar, dim_evento,
             dim_sector, dim_tarifa, dim_medio_pago RESTART IDENTITY;

    -- ─── 1. Dimensiones ─────────────────────────────────────────────────────

    -- dim_fecha: todos los días de los años en que hay compras o eventos
    INSERT INTO dim_fecha (sk_fecha, fecha, anio, trimestre, mes, nombre_mes, anio_mes,
                           dia, dia_semana, nombre_dia, fin_de_semana)
    SELECT to_char(d, 'YYYYMMDD')::int,
           d,
           EXTRACT(YEAR    FROM d)::int,
           EXTRACT(QUARTER FROM d)::int,
           EXTRACT(MONTH   FROM d)::int,
           (ARRAY['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio',
                  'Agosto','Septiembre','Octubre','Noviembre','Diciembre'])[EXTRACT(MONTH FROM d)::int],
           to_char(d, 'YYYY-MM'),
           EXTRACT(DAY     FROM d)::int,
           EXTRACT(ISODOW  FROM d)::int,
           (ARRAY['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])[EXTRACT(ISODOW FROM d)::int],
           EXTRACT(ISODOW  FROM d) IN (6, 7)
    FROM generate_series(
            (SELECT date_trunc('year', MIN(fecha)) FROM origen.compras),
            (SELECT date_trunc('year', MAX(fecha_fin)::timestamp) + INTERVAL '1 year - 1 day' FROM origen.eventos),
            INTERVAL '1 day'
         ) AS g (dia)
    CROSS JOIN LATERAL (SELECT g.dia::date AS d) AS x;
    GET DIAGNOSTICS v_fechas = ROW_COUNT;

    INSERT INTO dim_productora (id_empresa, nombre, cuit, cargo_servicio_pct)
    SELECT id_empresa, nombre, cuit, cargo_servicio_pct
    FROM origen.empresas;

    INSERT INTO dim_lugar (id_lugar, nombre, tipo, ciudad, provincia, es_propio)
    SELECT id_lugar, nombre, tipo, ciudad, provincia, id_empresa IS NOT NULL
    FROM origen.lugares;

    INSERT INTO dim_evento (id_evento, nombre, tipo, fecha_inicio, fecha_fin, estado)
    SELECT id_evento, nombre, tipo, fecha_inicio, fecha_fin, estado
    FROM origen.eventos;
    GET DIAGNOSTICS v_eventos = ROW_COUNT;

    INSERT INTO dim_sector (id_espacio, nombre, lugar, modalidad, capacidad)
    SELECT es.id_espacio, es.nombre, l.nombre, es.modalidad, es.capacidad
    FROM origen.espacios es
    JOIN origen.lugares l ON l.id_lugar = es.id_lugar;

    INSERT INTO dim_tarifa (id_tarifa, nombre, es_abono, precio_lista)
    SELECT id_tarifa, nombre, id_jornada IS NULL, precio
    FROM origen.tarifas;

    INSERT INTO dim_medio_pago (codigo, nombre)
    SELECT DISTINCT medio_pago,
           CASE medio_pago WHEN 'credito'       THEN 'Tarjeta de crédito'
                           WHEN 'debito'        THEN 'Tarjeta de débito'
                           WHEN 'transferencia' THEN 'Transferencia'
                           ELSE medio_pago END
    FROM origen.compras;

    -- ─── 2. Hechos ──────────────────────────────────────────────────────────
    -- La subconsulta "v" lee de la operativa (Extract) y prepara cada entrada (Transform).
    -- Los JOIN con las dimensiones cambian cada id por su sk_ (Load).
    --
    -- Reparto del cargo por servicio: la compra tiene un solo cargo (por ejemplo $100,01 para
    -- 3 entradas). Cada entrada lleva el cargo / cantidad truncado a 2 decimales ($33,33) y los
    -- centavos que sobran ($0,02) van a la primera entrada. Así la suma da exacto el cargo de
    -- la compra y la verificación coincide al centavo.
    INSERT INTO fact_ventas (id_entrada, id_compra, sk_fecha, sk_productora, sk_lugar, sk_evento,
                             sk_sector, sk_tarifa, sk_medio_pago,
                             cantidad, precio_pagado, cargo_servicio, dias_anticipacion)
    SELECT v.id_entrada,
           v.id_compra,
           to_char(v.fecha_compra, 'YYYYMMDD')::int,
           dp.sk_productora,
           dl.sk_lugar,
           de.sk_evento,
           ds.sk_sector,
           dt.sk_tarifa,
           dm.sk_medio_pago,
           1,
           v.precio_pagado,
           trunc(v.cargo_compra / v.entradas_compra, 2)
             + CASE WHEN v.orden = 1
                    THEN v.cargo_compra - trunc(v.cargo_compra / v.entradas_compra, 2) * v.entradas_compra
                    ELSE 0 END,
           v.fecha_evento - v.fecha_compra::date
    FROM (
        SELECT e.id_entrada, e.id_compra, e.id_tarifa, e.precio_pagado,
               c.fecha          AS fecha_compra,
               c.cargo_servicio AS cargo_compra,
               c.medio_pago,
               ev.id_evento, ev.id_empresa, ev.id_lugar,
               ev.fecha_inicio  AS fecha_evento,
               t.id_espacio,
               COUNT(*)     OVER (PARTITION BY e.id_compra)                     AS entradas_compra,
               ROW_NUMBER() OVER (PARTITION BY e.id_compra ORDER BY e.id_entrada) AS orden
        FROM origen.entradas e
        JOIN origen.compras  c  ON c.id_compra  = e.id_compra
        JOIN origen.tarifas  t  ON t.id_tarifa  = e.id_tarifa
        JOIN origen.eventos  ev ON ev.id_evento = e.id_evento
        WHERE c.estado = 'pagada'
    ) AS v
    JOIN dim_productora dp ON dp.id_empresa = v.id_empresa
    JOIN dim_lugar      dl ON dl.id_lugar   = v.id_lugar
    JOIN dim_evento     de ON de.id_evento  = v.id_evento
    JOIN dim_sector     ds ON ds.id_espacio = v.id_espacio
    JOIN dim_tarifa     dt ON dt.id_tarifa  = v.id_tarifa
    JOIN dim_medio_pago dm ON dm.codigo     = v.medio_pago;
    GET DIAGNOSTICS v_hechos = ROW_COUNT;

    -- ─── 3. Recrear claves foráneas e índices ───────────────────────────────
    ALTER TABLE fact_ventas
        ADD CONSTRAINT fact_ventas_fecha_fk      FOREIGN KEY (sk_fecha)      REFERENCES dim_fecha (sk_fecha),
        ADD CONSTRAINT fact_ventas_productora_fk FOREIGN KEY (sk_productora) REFERENCES dim_productora (sk_productora),
        ADD CONSTRAINT fact_ventas_lugar_fk      FOREIGN KEY (sk_lugar)      REFERENCES dim_lugar (sk_lugar),
        ADD CONSTRAINT fact_ventas_evento_fk     FOREIGN KEY (sk_evento)     REFERENCES dim_evento (sk_evento),
        ADD CONSTRAINT fact_ventas_sector_fk     FOREIGN KEY (sk_sector)     REFERENCES dim_sector (sk_sector),
        ADD CONSTRAINT fact_ventas_tarifa_fk     FOREIGN KEY (sk_tarifa)     REFERENCES dim_tarifa (sk_tarifa),
        ADD CONSTRAINT fact_ventas_medio_pago_fk FOREIGN KEY (sk_medio_pago) REFERENCES dim_medio_pago (sk_medio_pago);
    CREATE INDEX fact_ventas_fecha_idx      ON fact_ventas (sk_fecha);
    CREATE INDEX fact_ventas_productora_idx ON fact_ventas (sk_productora);
    CREATE INDEX fact_ventas_lugar_idx      ON fact_ventas (sk_lugar);
    CREATE INDEX fact_ventas_evento_idx     ON fact_ventas (sk_evento);
    CREATE INDEX fact_ventas_sector_idx     ON fact_ventas (sk_sector);
    CREATE INDEX fact_ventas_tarifa_idx     ON fact_ventas (sk_tarifa);
    CREATE INDEX fact_ventas_medio_idx      ON fact_ventas (sk_medio_pago);
    ANALYZE fact_ventas;   -- estadísticas al día para que las consultas elijan buenos planes

    -- ─── 4. Registro ────────────────────────────────────────────────────────
    INSERT INTO carga_log (inicio, fin, filas_fechas, filas_eventos, filas_hechos)
    VALUES (v_inicio, clock_timestamp(), v_fechas, v_eventos, v_hechos);

    RAISE NOTICE 'Carga terminada: % fechas, % eventos, % ventas (entradas)', v_fechas, v_eventos, v_hechos;
END;
$$;
