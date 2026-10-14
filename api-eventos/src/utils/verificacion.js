import { randomInt } from "node:crypto";
import bcrypt from "bcryptjs";
import { enviarCorreo } from "./correo.js";

// El nombre lo escribe el usuario: se escapa antes de meterlo en el HTML del mail
const escaparHtml = (texto) =>
  texto.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

export const MINUTOS_VIGENCIA = 15;
export const MAX_INTENTOS = 5;
export const SEGUNDOS_ENTRE_ENVIOS = 60;

// Genera un código nuevo (borra los anteriores del usuario), lo guarda hasheado y lo manda por mail.
// Recibe un cliente de pg para poder usarse dentro de una transacción.
export const enviarCodigo = async (db, usuario) => {
  const codigo = randomInt(0, 1_000_000).toString().padStart(6, "0");

  await db.query("DELETE FROM codigos_verificacion WHERE id_usuario = $1", [usuario.id_usuario]);
  await db.query(
    `INSERT INTO codigos_verificacion (id_usuario, codigo_hash, expira)
     VALUES ($1, $2, NOW() + make_interval(mins => $3))`,
    [usuario.id_usuario, await bcrypt.hash(codigo, 10), MINUTOS_VIGENCIA]
  );

  await enviarCorreo({
    para: usuario.email,
    asunto: `Tu código de Backstage: ${codigo}`,
    texto: `Hola ${usuario.nombre}, tu código para verificar el email es ${codigo}. Vence en ${MINUTOS_VIGENCIA} minutos.`,
    html: `<p>Hola ${escaparHtml(usuario.nombre)},</p>
           <p>Tu código para verificar el email es:</p>
           <p style="font-size:28px;font-weight:bold;letter-spacing:6px">${codigo}</p>
           <p>Vence en ${MINUTOS_VIGENCIA} minutos. Si no creaste una cuenta en Backstage, ignorá este mail.</p>`
  });
};
