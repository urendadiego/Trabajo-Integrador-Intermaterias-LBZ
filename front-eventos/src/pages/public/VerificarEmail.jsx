import { useEffect, useRef, useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { Alert, Button, Card, Form, Input, Typography } from "antd";
import { MailOutlined, SafetyOutlined } from "@ant-design/icons";
import { inicioDeRol, useAuth } from "../../context/auth.js";
import { mensajeDeError } from "../../services/api.js";
import * as authService from "../../services/authService.js";

const SEGUNDOS_ENTRE_ENVIOS = 60;

// Se llega desde el registro o desde el login (si la cuenta no está verificada).
// El email viene en location.state; si se entra directo, se pide.
function VerificarEmail() {
  const { usuario, verificar } = useAuth();
  const navigate = useNavigate();
  const { state } = useLocation();
  const [email, setEmail] = useState(state?.email ?? "");
  const [codigo, setCodigo] = useState("");
  const [error, setError] = useState("");
  const [aviso, setAviso] = useState(state?.email ? `Te mandamos un código de 6 números a ${state.email}` : "");
  const [enviando, setEnviando] = useState(false);
  const [espera, setEspera] = useState(state?.reenviar ? 0 : SEGUNDOS_ENTRE_ENVIOS);
  const reenvioInicial = useRef(false);

  // Cuenta regresiva para poder pedir otro código
  useEffect(() => {
    if (espera <= 0) return;
    const t = setTimeout(() => setEspera((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [espera]);

  const reenviar = async (destino = email) => {
    setError("");
    try {
      await authService.reenviarCodigo(destino);
      setAviso(`Te mandamos un código nuevo a ${destino}`);
      setEspera(SEGUNDOS_ENTRE_ENVIOS);
    } catch (err) {
      setError(mensajeDeError(err, "No se pudo mandar el código"));
    }
  };

  // Viene del login: el código que tenía pudo haber vencido, se manda uno nuevo
  useEffect(() => {
    if (state?.reenviar && state?.email && !reenvioInicial.current) {
      reenvioInicial.current = true;
      reenviar(state.email);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (usuario) {
    return <Navigate to={inicioDeRol(usuario.rol)} replace />;
  }

  const enviarCodigo = async (valor = codigo) => {
    if (valor.length !== 6 || !email) return;
    setError("");
    setEnviando(true);
    try {
      const verificado = await verificar(email, valor);
      navigate(inicioDeRol(verificado.rol), { replace: true });
    } catch (err) {
      setError(mensajeDeError(err, "No se pudo verificar el código"));
      setCodigo("");
      setEnviando(false);
    }
  };

  return (
    <div style={{ maxWidth: 420, margin: "40px auto" }}>
      <Card>
        <Typography.Title level={3} style={{ marginTop: 0 }}>Verificá tu email</Typography.Title>
        <Typography.Paragraph type="secondary">
          Ingresá el código que te llegó por mail. Si no lo ves, fijate en spam.
        </Typography.Paragraph>
        {aviso && !error && <Alert type="info" showIcon title={aviso} style={{ marginBottom: 16 }} />}
        {error && <Alert type="error" showIcon title={error} style={{ marginBottom: 16 }} />}

        <Form layout="vertical" requiredMark={false} onFinish={() => enviarCodigo()}>
          {!state?.email && (
            <Form.Item label="Email">
              <Input prefix={<MailOutlined />} type="email" value={email} onChange={(e) => setEmail(e.target.value.trim())} autoComplete="email" />
            </Form.Item>
          )}
          <Form.Item label="Código">
            <Input.OTP
              length={6}
              value={codigo}
              onChange={(valor) => {
                setCodigo(valor);
                enviarCodigo(valor);
              }}
              formatter={(v) => v.replace(/\D/g, "")}
              disabled={enviando}
            />
          </Form.Item>
          <Button type="primary" htmlType="submit" icon={<SafetyOutlined />} loading={enviando} disabled={codigo.length !== 6 || !email} block>
            Verificar
          </Button>
        </Form>

        <Button type="link" block style={{ marginTop: 8 }} disabled={espera > 0 || !email} onClick={() => reenviar()}>
          {espera > 0 ? `Pedir otro código en ${espera} s` : "Mandarme otro código"}
        </Button>

        <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0, textAlign: "center" }}>
          <Link to="/login">Volver al ingreso</Link>
        </Typography.Paragraph>
      </Card>
    </div>
  );
}

export default VerificarEmail;
