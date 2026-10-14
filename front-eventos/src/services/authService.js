import api from "./api.js";

export const login = (email, password) => api.post("/auth/login", { email, password });

export const registro = (datos) => api.post("/auth/registro", datos);

export const verificar = (email, codigo) => api.post("/auth/verificar", { email, codigo });

export const reenviarCodigo = (email) => api.post("/auth/reenviar-codigo", { email });

export const obtenerYo = () => api.get("/auth/yo");
