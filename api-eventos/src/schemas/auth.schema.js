import { z } from "zod";
import { opcional } from "./comunes.js";

const email = z.string().trim().toLowerCase().pipe(z.email("El email no es válido"));

// Datos de una persona con login. Los usa también el ABM de usuarios del superadmin.
export const camposUsuario = {
  email,
  password: z.string().min(6, "La contraseña debe tener al menos 6 caracteres").max(72),
  nombre: z.string().trim().min(1, "El nombre es obligatorio").max(100),
  apellido: opcional(z.string().trim().max(100)),
  dni: opcional(z.string().trim().regex(/^\d{7,10}$/, "El DNI tiene que tener solo números")),
  telefono: opcional(z.string().trim().max(30))
};

export const loginSchema = z.object({
  email,
  password: z.string().min(1, "La contraseña es obligatoria")
});

// Solo se registran clientes; los usuarios de las productoras los crea el superadmin.
export const registroSchema = z.object(camposUsuario);
