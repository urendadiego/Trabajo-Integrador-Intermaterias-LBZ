import { useEffect, useState } from "react";
import { AuthContext } from "./auth.js";
import { borrarToken, guardarToken, leerToken, onSesionExpirada } from "../services/api.js";
import * as authService from "../services/authService.js";

export function AuthProvider({ children }) {
  const [usuario, setUsuario] = useState(null);
  // Si hay un token guardado, hay que validarlo antes de mostrar rutas protegidas
  const [cargando, setCargando] = useState(() => Boolean(leerToken()));

  useEffect(() => {
    onSesionExpirada(() => setUsuario(null));

    if (!leerToken()) return;
    authService
      .obtenerYo()
      .then(({ data }) => setUsuario(data))
      .catch(() => borrarToken())
      .finally(() => setCargando(false));
  }, []);

  const iniciarSesion = ({ token, usuario }) => {
    guardarToken(token);
    setUsuario(usuario);
    return usuario;
  };

  const login = async (email, password) => {
    const { data } = await authService.login(email, password);
    return iniciarSesion(data);
  };

  // El registro no inicia sesión: primero hay que verificar el email con el código que llega por mail
  const registro = async (datos) => {
    const { data } = await authService.registro(datos);
    return data;
  };

  const verificar = async (email, codigo) => {
    const { data } = await authService.verificar(email, codigo);
    return iniciarSesion(data);
  };

  const logout = () => {
    borrarToken();
    setUsuario(null);
  };

  return (
    <AuthContext.Provider value={{ usuario, cargando, login, registro, verificar, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
