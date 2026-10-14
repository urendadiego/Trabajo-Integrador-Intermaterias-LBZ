import { useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { Alert, Button, Card, Form, Input, Typography } from "antd";
import { LockOutlined, LoginOutlined, MailOutlined } from "@ant-design/icons";
import { inicioDeRol, useAuth } from "../../context/auth.js";
import { mensajeDeError } from "../../services/api.js";

function Login() {
  const { usuario, login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [error, setError] = useState("");
  const [enviando, setEnviando] = useState(false);

  // Si ya tiene sesión, no tiene sentido mostrar el login
  if (usuario) {
    return <Navigate to={inicioDeRol(usuario.rol)} replace />;
  }

  const handleSubmit = async ({ email, password }) => {
    setError("");
    setEnviando(true);
    try {
      const logueado = await login(email, password);
      // Vuelve a la página que quería ver, o a la de inicio de su rol
      navigate(location.state?.desde ?? inicioDeRol(logueado.rol), { replace: true });
    } catch (err) {
      // Se registró pero nunca ingresó el código: a la pantalla de verificación, con un código nuevo
      if (err.response?.data?.motivo === "email_no_verificado") {
        navigate("/verificar", { state: { email, reenviar: true } });
        return;
      }
      setError(mensajeDeError(err, "No se pudo iniciar sesión"));
      setEnviando(false);
    }
  };

  return (
    <div style={{ maxWidth: 420, margin: "40px auto" }}>
      <Card>
        <Typography.Title level={3} style={{ marginTop: 0 }}>Ingresar</Typography.Title>
        {error && <Alert type="error" showIcon title={error} style={{ marginBottom: 16 }} />}

        <Form layout="vertical" onFinish={handleSubmit} requiredMark={false}>
          <Form.Item name="email" label="Email" rules={[{ required: true, message: "Ingresá tu email" }]}>
            <Input prefix={<MailOutlined />} type="email" autoComplete="email" autoFocus />
          </Form.Item>
          <Form.Item name="password" label="Contraseña" rules={[{ required: true, message: "Ingresá tu contraseña" }]}>
            <Input.Password prefix={<LockOutlined />} autoComplete="current-password" />
          </Form.Item>
          <Button type="primary" htmlType="submit" icon={<LoginOutlined />} loading={enviando} block>
            Ingresar
          </Button>
        </Form>

        <Typography.Paragraph type="secondary" style={{ marginTop: 16, marginBottom: 0, textAlign: "center" }}>
          ¿No tenés cuenta? <Link to="/registro">Creá una</Link> para comprar entradas.
        </Typography.Paragraph>
      </Card>

      {import.meta.env.DEV && (
        <Alert
          type="info"
          style={{ marginTop: 16 }}
          title="Usuarios de prueba (database/11_seed_demo.sql)"
          description={
            <>
              admin@backstage.com / admin123<br />
              staff@eventosdelcentro.com / demo123<br />
              lucia.gomez@mail.com / demo123
            </>
          }
        />
      )}
    </div>
  );
}

export default Login;
