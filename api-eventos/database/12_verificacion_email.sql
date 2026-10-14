-- 12 · Verificación del email
-- Al registrarse, el cliente recibe un código de 6 dígitos por mail y no puede iniciar sesión
-- hasta ingresarlo. Los usuarios que crea el superadmin quedan verificados.
-- Se puede correr varias veces.

-- Los usuarios que ya existen al agregar la columna quedan verificados (DEFAULT TRUE);
-- después el default pasa a FALSE para los nuevos. Si la columna ya existe, no cambia nada.
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE usuarios ALTER COLUMN email_verificado SET DEFAULT FALSE;

-- Un código vigente por usuario (al pedir uno nuevo se borran los anteriores).
-- Se guarda el hash, nunca el código.
CREATE TABLE IF NOT EXISTS codigos_verificacion (
    id_codigo      SERIAL PRIMARY KEY,
    id_usuario     INT          NOT NULL REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    codigo_hash    VARCHAR(100) NOT NULL,                       -- bcrypt
    intentos       INT          NOT NULL DEFAULT 0 CHECK (intentos >= 0),
    expira         TIMESTAMP    NOT NULL,
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS codigos_verificacion_id_usuario_idx ON codigos_verificacion (id_usuario);

-- Igual que en 09_seguridad.sql: que la API pública de Supabase no la exponga
ALTER TABLE codigos_verificacion ENABLE ROW LEVEL SECURITY;
