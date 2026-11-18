-- Tablas del data warehouse (correr en backstage_dw)
-- Proceso: venta de entradas. Grano: una entrada vendida en una compra pagada
DROP TABLE IF EXISTS fact_ventas, dim_fecha, dim_productora, dim_lugar, dim_evento,
                     dim_sector, dim_tarifa, dim_medio_pago, carga_log CASCADE;

-- Dimensiones
CREATE TABLE dim_fecha (
    sk_fecha        INT PRIMARY KEY,
    fecha           DATE NOT NULL UNIQUE,
    anio            INT  NOT NULL,
    trimestre       INT  NOT NULL,
    mes             INT  NOT NULL,
    nombre_mes      VARCHAR(10) NOT NULL,
    anio_mes        CHAR(7) NOT NULL,
    dia             INT  NOT NULL,
    dia_semana      INT  NOT NULL,
    nombre_dia      VARCHAR(10) NOT NULL,
    fin_de_semana   BOOLEAN NOT NULL
);

CREATE TABLE dim_productora (
    sk_productora      SERIAL PRIMARY KEY,
    id_empresa         INT NOT NULL UNIQUE,
    nombre             VARCHAR(150) NOT NULL,
    cuit               VARCHAR(13)  NOT NULL,
    cargo_servicio_pct NUMERIC(5,2) NOT NULL
);

CREATE TABLE dim_lugar (
    sk_lugar    SERIAL PRIMARY KEY,
    id_lugar    INT NOT NULL UNIQUE,
    nombre      VARCHAR(150) NOT NULL,
    tipo        VARCHAR(20)  NOT NULL,
    ciudad      VARCHAR(100) NOT NULL,
    provincia   VARCHAR(100) NOT NULL,
    es_propio   BOOLEAN NOT NULL
);

CREATE TABLE dim_evento (
    sk_evento     SERIAL PRIMARY KEY,
    id_evento     INT NOT NULL UNIQUE,
    nombre        VARCHAR(150) NOT NULL,
    tipo          VARCHAR(10)  NOT NULL,
    fecha_inicio  DATE NOT NULL,
    fecha_fin     DATE NOT NULL,
    estado        VARCHAR(12)  NOT NULL
);

CREATE TABLE dim_sector (
    sk_sector   SERIAL PRIMARY KEY,
    id_espacio  INT NOT NULL UNIQUE,
    nombre      VARCHAR(100) NOT NULL,
    lugar       VARCHAR(150) NOT NULL,
    modalidad   VARCHAR(10)  NOT NULL,
    capacidad   INT NOT NULL
);

CREATE TABLE dim_tarifa (
    sk_tarifa    SERIAL PRIMARY KEY,
    id_tarifa    INT NOT NULL UNIQUE,
    nombre       VARCHAR(60) NOT NULL,
    es_abono     BOOLEAN NOT NULL,
    precio_lista NUMERIC(12,2) NOT NULL
);

CREATE TABLE dim_medio_pago (
    sk_medio_pago SERIAL PRIMARY KEY,
    codigo        VARCHAR(15) NOT NULL UNIQUE,
    nombre        VARCHAR(30) NOT NULL
);

-- Tabla de hechos
CREATE TABLE fact_ventas (
    id_entrada        INT PRIMARY KEY,
    id_compra         INT NOT NULL,
    sk_fecha          INT NOT NULL,
    sk_productora     INT NOT NULL,
    sk_lugar          INT NOT NULL,
    sk_evento         INT NOT NULL,
    sk_sector         INT NOT NULL,
    sk_tarifa         INT NOT NULL,
    sk_medio_pago     INT NOT NULL,
    cantidad          INT NOT NULL DEFAULT 1,
    precio_pagado     NUMERIC(12,2) NOT NULL,
    cargo_servicio    NUMERIC(12,2) NOT NULL,
    dias_anticipacion INT NOT NULL,
    CONSTRAINT fact_ventas_fecha_fk      FOREIGN KEY (sk_fecha)      REFERENCES dim_fecha (sk_fecha),
    CONSTRAINT fact_ventas_productora_fk FOREIGN KEY (sk_productora) REFERENCES dim_productora (sk_productora),
    CONSTRAINT fact_ventas_lugar_fk      FOREIGN KEY (sk_lugar)      REFERENCES dim_lugar (sk_lugar),
    CONSTRAINT fact_ventas_evento_fk     FOREIGN KEY (sk_evento)     REFERENCES dim_evento (sk_evento),
    CONSTRAINT fact_ventas_sector_fk     FOREIGN KEY (sk_sector)     REFERENCES dim_sector (sk_sector),
    CONSTRAINT fact_ventas_tarifa_fk     FOREIGN KEY (sk_tarifa)     REFERENCES dim_tarifa (sk_tarifa),
    CONSTRAINT fact_ventas_medio_pago_fk FOREIGN KEY (sk_medio_pago) REFERENCES dim_medio_pago (sk_medio_pago)
);

-- Índices
CREATE INDEX fact_ventas_fecha_idx      ON fact_ventas (sk_fecha);
CREATE INDEX fact_ventas_productora_idx ON fact_ventas (sk_productora);
CREATE INDEX fact_ventas_lugar_idx      ON fact_ventas (sk_lugar);
CREATE INDEX fact_ventas_evento_idx     ON fact_ventas (sk_evento);
CREATE INDEX fact_ventas_sector_idx     ON fact_ventas (sk_sector);
CREATE INDEX fact_ventas_tarifa_idx     ON fact_ventas (sk_tarifa);
CREATE INDEX fact_ventas_medio_idx      ON fact_ventas (sk_medio_pago);

-- Registro de cargas
CREATE TABLE carga_log (
    id_carga       SERIAL PRIMARY KEY,
    inicio         TIMESTAMP NOT NULL,
    fin            TIMESTAMP NOT NULL,
    filas_fechas   INT NOT NULL,
    filas_eventos  INT NOT NULL,
    filas_hechos   INT NOT NULL
);
