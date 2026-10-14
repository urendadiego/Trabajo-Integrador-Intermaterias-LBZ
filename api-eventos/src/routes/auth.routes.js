import { Router } from "express";
import { login, registro, verificar, reenviarCodigo, yo } from "../controllers/auth.controller.js";
import { autenticar } from "../middlewares/autenticar.js";
import { validar } from "../middlewares/validar.js";
import { loginSchema, registroSchema, verificarSchema, reenviarSchema } from "../schemas/auth.schema.js";

const router = Router();

router.post("/login", validar(loginSchema), login);
router.post("/registro", validar(registroSchema), registro);
router.post("/verificar", validar(verificarSchema), verificar);
router.post("/reenviar-codigo", validar(reenviarSchema), reenviarCodigo);
router.get("/yo", autenticar, yo);

export default router;
