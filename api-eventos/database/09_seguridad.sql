-- 09 · Seguridad
-- Supabase publica las tablas del esquema public en su API REST (cualquiera con la anon key).
-- RLS activado y SIN políticas = esa API no puede leer ni escribir nada.
-- Nuestra API entra con el usuario postgres, que saltea RLS, así que no le afecta:
-- el aislamiento entre productoras lo sigue haciendo el backend (ver der.md / plan-desarrollo.md).
-- Las vistas usan security_invoker para respetar el RLS de sus tablas (si no, se podrían leer por la API).
-- Se puede correr varias veces. En el Postgres de Docker no hace daño.

DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
    END LOOP;

    FOR r IN SELECT viewname FROM pg_views WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', r.viewname);
    END LOOP;
END $$;
