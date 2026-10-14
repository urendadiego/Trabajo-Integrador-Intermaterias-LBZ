import { ZodError } from "zod";
import { ErrorHttp } from "../utils/ErrorHttp.js";

// Mensajes para las restricciones UNIQUE que el usuario puede chocar.
// Las que no están acá responden un mensaje genérico.
const DUPLICADOS = {
  empresas_cuit_key: "Ya existe una productora con ese CUIT",
  usuarios_email_key: "Ya existe un usuario con ese email",
  lugares_nombre_uk: "Ya existe un lugar con ese nombre",
  escenarios_nombre_uk: "El lugar ya tiene un escenario con ese nombre",
  espacios_nombre_uk: "El lugar ya tiene un sector con ese nombre",
  artistas_nombre_uk: "Ya cargaste un artista con ese nombre",
  jornadas_fecha_uk: "El evento ya tiene una jornada en esa fecha",
  tarifas_nombre_uk: "Ya existe una tarifa con ese nombre para ese sector y jornada",
  ingresos_entrada_jornada_uk: "La entrada ya ingresó en esta jornada"
};

const SUPERPOSICIONES = {
  presentaciones_escenario_excl: "El escenario ya tiene una presentación en ese horario",
  presentaciones_artista_excl: "El artista ya tiene otra presentación en ese horario"
};

// Traduce los errores de PostgreSQL (docs/base-de-datos/der.md) a respuestas HTTP.
const errorDePostgres = (error) => {
  switch (error.code) {
    case "23505": // unique_violation
      return [409, DUPLICADOS[error.constraint] ?? "Ya existe un registro con esos datos"];
    case "23P01": // exclusion_violation
      return [409, SUPERPOSICIONES[error.constraint] ?? "Se superpone con otro registro"];
    case "23001": // restrict_violation: FK con ON DELETE RESTRICT
      return [409, "No se puede borrar porque tiene datos asociados"];
    case "23503": // foreign_key_violation
      // Al borrar: hay filas que dependen de esta. Al insertar/editar: referencia inexistente.
      return error.message.startsWith("update or delete")
        ? [409, "No se puede borrar porque tiene datos asociados"]
        : [400, "Hace referencia a un dato que no existe o no corresponde"];
    case "23514": // check_violation: los triggers mandan su propio mensaje, los CHECK tienen nombre
      return [400, error.constraint ? "Los datos no cumplen una regla de la base" : error.message];
    case "23502": // not_null_violation
      return [400, `Falta el campo ${error.column}`];
    case "22P02": // invalid_text_representation
    case "22007": // invalid_datetime_format
    case "22008": // datetime_field_overflow
      return [400, "Algún dato tiene un formato inválido"];
    default:
      return null;
  }
};

// Middleware de errores (4 parámetros, siempre al final). En Express 5 los errores
// de los controllers async llegan solos, sin try/catch.
// eslint-disable-next-line no-unused-vars
export const manejarErrores = (error, req, res, next) => {
  if (error instanceof ErrorHttp) {
    return res.status(error.status).json({ mensaje: error.message, ...error.datos });
  }

  if (error instanceof ZodError) {
    return res.status(400).json({
      mensaje: "Hay datos inválidos",
      errores: error.issues.map((i) => ({ campo: i.path.join("."), mensaje: i.message }))
    });
  }

  if (error.type === "entity.parse.failed") {
    return res.status(400).json({ mensaje: "El cuerpo del pedido no es un JSON válido" });
  }

  const pg = errorDePostgres(error);
  if (pg) {
    return res.status(pg[0]).json({ mensaje: pg[1] });
  }

  console.error(error);
  res.status(500).json({ mensaje: "Error interno del servidor" });
};
