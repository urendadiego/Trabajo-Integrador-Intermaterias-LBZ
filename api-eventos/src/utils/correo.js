import nodemailer from "nodemailer";

// Mails con una cuenta de Gmail (GMAIL_USUARIO + GMAIL_CLAVE_APP, una "contraseña de aplicación").
// Si no están en el .env, el mail no se manda y se muestra en la consola: así se puede probar sin Gmail.
const configurado = Boolean(process.env.GMAIL_USUARIO && process.env.GMAIL_CLAVE_APP);

const transporte = configurado
  ? nodemailer.createTransport({
      service: "gmail",
      auth: { user: process.env.GMAIL_USUARIO, pass: process.env.GMAIL_CLAVE_APP }
    })
  : null;

export const enviarCorreo = async ({ para, asunto, texto, html }) => {
  if (!transporte) {
    console.log(`[correo sin Gmail configurado] Para: ${para} | ${asunto}\n${texto}`);
    return;
  }
  await transporte.sendMail({ from: `"Backstage" <${process.env.GMAIL_USUARIO}>`, to: para, subject: asunto, text: texto, html });
};
