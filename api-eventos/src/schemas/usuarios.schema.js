import { z } from "zod";
import { camposUsuario } from "./auth.schema.js";

const ROLES = ["superadmin", "empresa", "cliente"];
const idEmpresa = z.coerce.number().int().positive("La productora no es válida");

// RN-03: el personal de una productora pertenece a una sola; superadmin y clientes, a ninguna.
export const crearUsuarioSchema = z
  .object({
    ...camposUsuario,
    rol: z.enum(ROLES, { error: "El rol tiene que ser superadmin, empresa o cliente" }),
    id_empresa: idEmpresa.nullable().optional(),
    activo: z.boolean().optional()
  })
  .refine((u) => (u.rol === "empresa") === (u.id_empresa != null), {
    path: ["id_empresa"],
    message: "Solo los usuarios de rol empresa tienen productora, y es obligatoria"
  });

// En la edición todo es opcional y el rol no se cambia (un cliente con compras no puede pasar a ser personal).
// La contraseña, si viene, se reemplaza.
export const editarUsuarioSchema = z.object({
  ...camposUsuario,
  id_empresa: idEmpresa,
  activo: z.boolean()
}).partial();

// GET /api/admin/usuarios?rol=empresa&id_empresa=2&activo=true&buscar=lucia
export const filtrosUsuariosSchema = z.object({
  rol: z.enum(ROLES).optional(),
  id_empresa: idEmpresa.optional(),
  activo: z.enum(["true", "false"]).transform((v) => v === "true").optional(),
  buscar: z.string().trim().min(1).max(100).optional()
});
