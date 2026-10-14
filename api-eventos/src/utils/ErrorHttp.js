// Error con código HTTP. Se lanza desde cualquier controller o middleware y lo responde manejarErrores.
// Ej.: throw new ErrorHttp(404, "Empresa no encontrada");
// "datos" se suma a la respuesta, para que el front distinga casos: { motivo: "email_no_verificado" }
export class ErrorHttp extends Error {
  constructor(status, mensaje, datos = {}) {
    super(mensaje);
    this.status = status;
    this.datos = datos;
  }
}
