-- ============================================================================
-- DW · 04 · Tablas del data warehouse (modelo estrella)
-- ----------------------------------------------------------------------------
-- Se corre en la base: backstage_dw
--
-- Proceso de negocio: VENTA DE ENTRADAS
-- Grano:              una fila de fact_ventas = UNA ENTRADA vendida en una compra pagada
--
-- Preguntas que responde:
--   1. ¿Cuánto recauda cada productora por mes, y cuánto cobra la plataforma en cargo por servicio?
--   2. ¿Qué sectores y tarifas venden más en cada evento?
--   3. ¿Con cuánta anticipación compra la gente?
--   4. ¿Qué medios de pago se usan, por productora y por tipo de lugar?
--
-- Convenciones:
--   · sk_...  = clave sustituta (surrogate key): la genera el DW, no viene de la operativa
--   · id_...  = id original de la operativa; se guarda para poder cruzar en la carga
--   · Las dimensiones están desnormalizadas a propósito (por ejemplo, dim_sector repite el
--     nombre del lugar): en el DW nadie escribe, así que la redundancia no trae problemas
--     y las consultas necesitan menos JOIN.
-- ============================================================================

DROP TABLE IF EXISTS fact_ventas, dim_fecha, dim_productora, dim_lugar, dim_evento,
                     dim_sector, dim_tarifa, dim_medio_pago, carga_log CASCADE;

-- ─── Dimensiones ────────────────────────────────────────────────────────────

-- Cuándo se compró. No viene de la operativa: se genera con generate_series.
-- La clave es la fecha como número AAAAMMDD (20261118): se lee a simple vista
-- y se calcula sin buscar en la tabla.
CREATE TABLE dim_fecha (
    sk_fecha        INT PRIMARY KEY,           -- AAAAMMDD
    fecha           DATE NOT NULL UNIQUE,
    anio            INT  NOT NULL,
    trimestre       INT  NOT NULL,
    mes             INT  NOT NULL,
    nombre_mes      VARCHAR(10) NOT NULL,
    anio_mes        CHAR(7) NOT NULL,          -- '2026-11', cómodo para agrupar y ordenar
    dia             INT  NOT NULL,
    dia_semana      INT  NOT NULL,             -- 1 = lunes … 7 = domingo
    nombre_dia      VARCHAR(10) NOT NULL,
    fin_de_semana   BOOLEAN NOT NULL
);

-- Quién organiza (el tenant de Backstage)
CREATE TABLE dim_productora (
    sk_productora      SERIAL PRIMARY KEY,
    id_empresa         INT NOT NULL UNIQUE,
    nombre             VARCHAR(150) NOT NULL,
    cuit               VARCHAR(13)  NOT NULL,
    cargo_servicio_pct NUMERIC(5,2) NOT NULL
);

-- Dónde se hace
CREATE TABLE dim_lugar (
    sk_lugar    SERIAL PRIMARY KEY,
    id_lugar    INT NOT NULL UNIQUE,
    nombre      VARCHAR(150) NOT NULL,
    tipo        VARCHAR(20)  NOT NULL,         -- estadio, arena, teatro, predio, club, otro
    ciudad      VARCHAR(100) NOT NULL,
    provincia   VARCHAR(100) NOT NULL,
    es_propio   BOOLEAN NOT NULL               -- FALSE = lugar de la plataforma
);

-- Qué evento
CREATE TABLE dim_evento (
    sk_evento     SERIAL PRIMARY KEY,
    id_evento     INT NOT NULL UNIQUE,
    nombre        VARCHAR(150) NOT NULL,
    tipo          VARCHAR(10)  NOT NULL,       -- recital, festival
    fecha_inicio  DATE NOT NULL,
    fecha_fin     DATE NOT NULL,
    estado        VARCHAR(12)  NOT NULL
);

-- En qué sector del lugar (Campo, Platea…). Sale de la tabla espacios.
CREATE TABLE dim_sector (
    sk_sector   SERIAL PRIMARY KEY,
    id_espacio  INT NOT NULL UNIQUE,
    nombre      VARCHAR(100) NOT NULL,
    lugar       VARCHAR(150) NOT NULL,         -- desnormalizado: evita un JOIN para mostrarlo
    modalidad   VARCHAR(10)  NOT NULL,         -- de_pie, sentado
    capacidad   INT NOT NULL
);

-- Con qué tarifa (Preventa, General, Abono…)
CREATE TABLE dim_tarifa (
    sk_tarifa    SERIAL PRIMARY KEY,
    id_tarifa    INT NOT NULL UNIQUE,
    nombre       VARCHAR(60) NOT NULL,
    es_abono     BOOLEAN NOT NULL,             -- TRUE = vale para todas las jornadas
    precio_lista NUMERIC(12,2) NOT NULL
);

-- Cómo se pagó
CREATE TABLE dim_medio_pago (
    sk_medio_pago SERIAL PRIMARY KEY,
    codigo        VARCHAR(15) NOT NULL UNIQUE, -- el valor de compras.medio_pago
    nombre        VARCHAR(30) NOT NULL
);

-- ─── Tabla de hechos ────────────────────────────────────────────────────────
-- Una fila por entrada vendida. Las sk_ apuntan a las dimensiones; el resto son medidas.
CREATE TABLE fact_ventas (
    id_entrada        INT PRIMARY KEY,         -- dimensión degenerada: identifica la fila, no tiene tabla propia
    id_compra         INT NOT NULL,            -- dimensión degenerada: permite contar compras (COUNT DISTINCT)
    sk_fecha          INT NOT NULL,
    sk_productora     INT NOT NULL,
    sk_lugar          INT NOT NULL,
    sk_evento         INT NOT NULL,
    sk_sector         INT NOT NULL,
    sk_tarifa         INT NOT NULL,
    sk_medio_pago     INT NOT NULL,
    -- Medidas
    cantidad          INT NOT NULL DEFAULT 1,  -- siempre 1: SUM(cantidad) = entradas vendidas
    precio_pagado     NUMERIC(12,2) NOT NULL,  -- lo que cobra la productora por esta entrada
    cargo_servicio    NUMERIC(12,2) NOT NULL,  -- parte del cargo de la compra que le toca a esta entrada (lo cobra la plataforma)
    dias_anticipacion INT NOT NULL,            -- fecha del evento − fecha de compra
    -- Claves foráneas con nombre: el procedimiento de carga las quita y las vuelve a crear por nombre
    CONSTRAINT fact_ventas_fecha_fk      FOREIGN KEY (sk_fecha)      REFERENCES dim_fecha (sk_fecha),
    CONSTRAINT fact_ventas_productora_fk FOREIGN KEY (sk_productora) REFERENCES dim_productora (sk_productora),
    CONSTRAINT fact_ventas_lugar_fk      FOREIGN KEY (sk_lugar)      REFERENCES dim_lugar (sk_lugar),
    CONSTRAINT fact_ventas_evento_fk     FOREIGN KEY (sk_evento)     REFERENCES dim_evento (sk_evento),
    CONSTRAINT fact_ventas_sector_fk     FOREIGN KEY (sk_sector)     REFERENCES dim_sector (sk_sector),
    CONSTRAINT fact_ventas_tarifa_fk     FOREIGN KEY (sk_tarifa)     REFERENCES dim_tarifa (sk_tarifa),
    CONSTRAINT fact_ventas_medio_pago_fk FOREIGN KEY (sk_medio_pago) REFERENCES dim_medio_pago (sk_medio_pago)
);

-- Índices en las claves foráneas: son las columnas por las que se filtra y agrupa.
-- (El procedimiento de carga también los quita y los recrea: ver 05_procedimiento_carga.sql)
CREATE INDEX fact_ventas_fecha_idx      ON fact_ventas (sk_fecha);
CREATE INDEX fact_ventas_productora_idx ON fact_ventas (sk_productora);
CREATE INDEX fact_ventas_lugar_idx      ON fact_ventas (sk_lugar);
CREATE INDEX fact_ventas_evento_idx     ON fact_ventas (sk_evento);
CREATE INDEX fact_ventas_sector_idx     ON fact_ventas (sk_sector);
CREATE INDEX fact_ventas_tarifa_idx     ON fact_ventas (sk_tarifa);
CREATE INDEX fact_ventas_medio_idx      ON fact_ventas (sk_medio_pago);

-- ─── Registro de cargas ─────────────────────────────────────────────────────
-- Cada CALL cargar_dw() deja una fila: sirve para mostrar que la carga se puede repetir.
CREATE TABLE carga_log (
    id_carga       SERIAL PRIMARY KEY,
    inicio         TIMESTAMP NOT NULL,
    fin            TIMESTAMP NOT NULL,
    filas_fechas   INT NOT NULL,
    filas_eventos  INT NOT NULL,
    filas_hechos   INT NOT NULL
);
