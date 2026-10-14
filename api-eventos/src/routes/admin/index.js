import { Router } from "express";
import { autenticar } from "../../middlewares/autenticar.js";
import { permitir } from "../../middlewares/permitir.js";
import empresasRouter from "./empresas.routes.js";
import usuariosRouter from "./usuarios.routes.js";

// /api/admin/*: todo lo de acá es solo para el superadmin
const router = Router();

router.use(autenticar, permitir("superadmin"));
router.use("/empresas", empresasRouter);
router.use("/usuarios", usuariosRouter);

export default router;
