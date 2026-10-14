import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { Alert, Button, Card, Col, Form, Input, Row, Typography } from "antd";
import { UserAddOutlined } from "@ant-design/icons";
import { inicioDeRol, useAuth } from "../../context/auth.js";
import { erroresPorCampo, mensajeDeError } from "../../services/api.js";

// Alta de clientes (el público que compra entradas)
function Registro() {
  const { usuario, registro } = useAuth();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [error, setError] = useState("");
  const [enviando, setEnviando] = useState(false);

  if (usuario) {
    return <Navigate to={inicioDeRol(usuario.rol)} replace />;
  }

  const handleSubmit = async ({ confirmar: _confirmar, ...datos }) => {
    setError("");
    setEnviando(true);
    try {
      await registro(datos);
      // La cuenta queda creada pero hay que verificar el email con el código que llega por mail
      navigate("/verificar", { replace: true, state: { email: datos.email } });
    } catch (err) {
      // Los errores de validación de la API se muestran debajo de cada campo
      const campos = erroresPorCampo(err);
      form.setFields(Object.entries(campos).map(([name, mensaje]) => ({ name, errors: [mensaje] })));
      if (Object.keys(campos).length === 0) setError(mensajeDeError(err, "No se pudo crear la cuenta"));
      setEnviando(false);
    }
  };

  return (
    <div style={{ maxWidth: 560, margin: "40px auto" }}>
      <Card>
        <Typography.Title level={3} style={{ marginTop: 0 }}>Crear cuenta</Typography.Title>
        <Typography.Paragraph type="secondary">
          Con tu cuenta comprás entradas y las ves en tu celular.
        </Typography.Paragraph>
        {error && <Alert type="error" showIcon title={error} style={{ marginBottom: 16 }} />}

        <Form form={form} layout="vertical" onFinish={handleSubmit}>
          <Row gutter={16}>
            <Col xs={24} sm={12}>
              <Form.Item name="nombre" label="Nombre" rules={[{ required: true, whitespace: true, message: "Ingresá tu nombre" }]}>
                <Input maxLength={100} autoComplete="given-name" />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item name="apellido" label="Apellido">
                <Input maxLength={100} autoComplete="family-name" />
              </Form.Item>
            </Col>
            <Col span={24}>
              <Form.Item name="email" label="Email" rules={[{ required: true, type: "email", message: "Ingresá un email válido" }]}>
                <Input autoComplete="email" maxLength={150} />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item name="password" label="Contraseña" rules={[{ required: true, min: 6, message: "Al menos 6 caracteres" }]}>
                <Input.Password autoComplete="new-password" />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item
                name="confirmar"
                label="Repetir contraseña"
                dependencies={["password"]}
                rules={[
                  { required: true, message: "Repetí la contraseña" },
                  ({ getFieldValue }) => ({
                    validator: (_, valor) =>
                      !valor || valor === getFieldValue("password")
                        ? Promise.resolve()
                        : Promise.reject(new Error("Las contraseñas no coinciden"))
                  })
                ]}
              >
                <Input.Password autoComplete="new-password" />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item name="dni" label="DNI" rules={[{ pattern: /^\d{7,10}$/, message: "Solo números, sin puntos" }]}>
                <Input maxLength={10} inputMode="numeric" />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item name="telefono" label="Teléfono">
                <Input maxLength={30} autoComplete="tel" />
              </Form.Item>
            </Col>
          </Row>
          <Button type="primary" htmlType="submit" icon={<UserAddOutlined />} loading={enviando} block>
            Crear cuenta
          </Button>
        </Form>

        <Typography.Paragraph type="secondary" style={{ marginTop: 16, marginBottom: 0, textAlign: "center" }}>
          ¿Ya tenés cuenta? <Link to="/login">Ingresá</Link>
        </Typography.Paragraph>
      </Card>
    </div>
  );
}

export default Registro;
