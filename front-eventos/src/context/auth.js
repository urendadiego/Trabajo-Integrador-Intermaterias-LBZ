import { createContext, useContext } from "react";

export const AuthContext = createContext(null);

// { usuario, cargando, login, registro, verificar, logout } (ver AuthProvider.jsx)
export const useAuth = () => useContext(AuthContext);

// Pantalla de inicio de cada rol (a dónde va después de loguearse)
export const inicioDeRol = (rol) =>
  ({ superadmin: "/admin", empresa: "/panel" })[rol] ?? "/";
