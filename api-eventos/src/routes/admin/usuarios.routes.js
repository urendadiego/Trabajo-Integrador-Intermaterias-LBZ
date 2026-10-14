import { Router } from "express";
import {
  obtenerUsuarios,
  obtenerUsuario,
  crearUsuario,
  editarUsuario,
  eliminarUsuario
} from "../../controllers/admin/usuarios.controller.js";
import { validar } from "../../middlewares/validar.js";
import { idParams } from "../../schemas/comunes.js";
import { crearUsuarioSchema, editarUsuarioSchema } from "../../schemas/usuarios.schema.js";

const router = Router();

router.get("/", obtenerUsuarios);
router.get("/:id", validar(idParams, "params"), obtenerUsuario);
router.post("/", validar(crearUsuarioSchema), crearUsuario);
router.put("/:id", validar(idParams, "params"), validar(editarUsuarioSchema), editarUsuario);
router.delete("/:id", validar(idParams, "params"), eliminarUsuario);

export default router;
