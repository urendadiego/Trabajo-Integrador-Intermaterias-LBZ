import bcrypt from "bcryptjs";
import pool from "../../data/db.js";
import { ErrorHttp } from "../../utils/ErrorHttp.js";
import { filtrosUsuariosSchema } from "../../schemas/usuarios.schema.js";

// Nunca se devuelve el hash de la contraseña
const SELECT_USUARIO = `
  SELECT u.id_usuario, u.email, u.nombre, u.apellido, u.dni, u.telefono, u.rol,
         u.id_empresa, e.nombre AS empresa, u.activo, u.email_verificado, u.fecha_creacion
  FROM usuarios u
  LEFT JOIN empresas e ON e.id_empresa = u.id_empresa`;

// Columnas que se pueden escribir desde el body (ya validado con zod). La contraseña va aparte.
const COLUMNAS = ["email", "nombre", "apellido", "dni", "telefono", "rol", "id_empresa", "activo"];

const buscarUsuario = async (id) => {
  const { rows } = await pool.query(`${SELECT_USUARIO} WHERE u.id_usuario = $1`, [id]);
  if (!rows[0]) {
    throw new ErrorHttp(404, "Usuario no encontrado");
  }
  return rows[0];
};

// El personal solo se puede asignar a una productora que exista y esté activa
const verificarEmpresa = async (idEmpresa) => {
  const { rows } = await pool.query("SELECT activo FROM empresas WHERE id_empresa = $1", [idEmpresa]);
  if (!rows[0]) {
    throw new ErrorHttp(400, "La productora no existe");
  }
  if (!rows[0].activo) {
    throw new ErrorHttp(400, "La productora está dada de baja");
  }
};

// Al dar de baja o borrar un superadmin: no puede ser uno mismo ni el último activo
const verificarBajaSuperadmin = async (usuario, req) => {
  if (usuario.rol !== "superadmin") {
    return;
  }
  if (usuario.id_usuario === req.usuario.id_usuario) {
    throw new ErrorHttp(400, "No podés darte de baja ni borrarte a vos mismo");
  }
  const { rows } = await pool.query(
    "SELECT COUNT(*)::int AS otros FROM usuarios WHERE rol = 'superadmin' AND activo AND id_usuario <> $1",
    [usuario.id_usuario]
  );
  if (rows[0].otros === 0) {
    throw new ErrorHttp(400, "Tiene que quedar al menos un superadmin activo");
  }
};

export const obtenerUsuarios = async (req, res) => {
  const filtros = filtrosUsuariosSchema.parse(req.query);
  const condiciones = [];
  const valores = [];

  for (const campo of ["rol", "id_empresa", "activo"]) {
    if (filtros[campo] !== undefined) {
      valores.push(filtros[campo]);
      condiciones.push(`u.${campo} = $${valores.length}`);
    }
  }
  if (filtros.buscar) {
    valores.push(`%${filtros.buscar}%`);
    const n = valores.length;
    condiciones.push(`(u.nombre ILIKE $${n} OR u.apellido ILIKE $${n} OR u.email ILIKE $${n} OR u.dni ILIKE $${n})`);
  }

  const where = condiciones.length ? `WHERE ${condiciones.join(" AND ")}` : "";
  const { rows } = await pool.query(`${SELECT_USUARIO} ${where} ORDER BY u.id_usuario`, valores);
  res.json(rows);
};

export const obtenerUsuario = async (req, res) => {
  res.json(await buscarUsuario(req.params.id));
};

export const crearUsuario = async (req, res) => {
  if (req.body.rol === "empresa") {
    await verificarEmpresa(req.body.id_empresa);
  }

  const columnas = COLUMNAS.filter((c) => req.body[c] !== undefined);
  const valores = columnas.map((c) => req.body[c]);
  columnas.push("password_hash", "email_verificado");
  // Los crea el superadmin: no pasan por la verificación del email
  valores.push(await bcrypt.hash(req.body.password, 10), true);
  const marcadores = columnas.map((_, i) => `$${i + 1}`);

  const { rows } = await pool.query(
    `INSERT INTO usuarios (${columnas.join(", ")}) VALUES (${marcadores.join(", ")}) RETURNING id_usuario`,
    valores
  );
  res.status(201).json(await buscarUsuario(rows[0].id_usuario));
};

export const editarUsuario = async (req, res) => {
  const usuario = await buscarUsuario(req.params.id);

  if (req.body.id_empresa !== undefined) {
    if (usuario.rol !== "empresa") {
      throw new ErrorHttp(400, "Solo los usuarios de rol empresa tienen productora");
    }
    await verificarEmpresa(req.body.id_empresa);
  }
  if (req.body.activo === false && usuario.activo) {
    await verificarBajaSuperadmin(usuario, req);
  }

  // Los campos que no vienen mantienen su valor; los opcionales vacíos ("" o null) quedan en NULL
  const columnas = COLUMNAS.filter((c) => req.body[c] !== undefined);
  const valores = columnas.map((c) => req.body[c]);
  if (req.body.password !== undefined) {
    columnas.push("password_hash");
    valores.push(await bcrypt.hash(req.body.password, 10));
  }
  if (columnas.length === 0) {
    return res.json(usuario);
  }

  const asignaciones = columnas.map((c, i) => `${c} = $${i + 1}`);
  await pool.query(
    `UPDATE usuarios SET ${asignaciones.join(", ")} WHERE id_usuario = $${columnas.length + 1}`,
    [...valores, usuario.id_usuario]
  );
  res.json(await buscarUsuario(usuario.id_usuario));
};

// Solo se puede borrar un usuario sin compras. Si tiene, la FK lo impide y manejarErrores
// devuelve 409: en ese caso se da de baja con activo = false (der.md, reglas de borrado).
export const eliminarUsuario = async (req, res) => {
  const usuario = await buscarUsuario(req.params.id);
  await verificarBajaSuperadmin(usuario, req);

  await pool.query("DELETE FROM usuarios WHERE id_usuario = $1", [usuario.id_usuario]);
  res.status(204).send();
};
