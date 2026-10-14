-- 00 · Reset (SOLO DESARROLLO)
-- Borra todas las tablas, vistas y funciones de Backstage.
-- CUIDADO: la base de Supabase es compartida por el grupo. Avisar antes de correrlo.

DROP VIEW IF EXISTS v_recaudacion, v_asistencia, v_disponibilidad, v_cartelera, v_lugares CASCADE;

DROP TABLE IF EXISTS
    ingresos, entradas, compras, tarifas,
    presentaciones, evento_escenarios, jornadas, eventos, artistas,
    elementos_plano, espacios, escenarios, lugares,
    codigos_verificacion, usuarios, empresas
CASCADE;

DROP FUNCTION IF EXISTS
    fn_eventos_lugar_valido(),
    fn_jornadas_en_rango(),
    fn_eventos_fechas_jornadas(),
    fn_presentacion_en_jornada(),
    fn_espacios_minimo_uno(),
    fn_compras_solo_clientes(),
    fn_ingresos_validos()
CASCADE;
