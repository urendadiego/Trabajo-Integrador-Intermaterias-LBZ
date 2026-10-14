import { Navigate, Routes, Route, useParams } from "react-router-dom";
import RutaProtegida from "./routes/RutaProtegida.jsx";
import PublicLayout from "./layouts/PublicLayout.jsx";
import AdminLayout from "./layouts/AdminLayout.jsx";
import PanelLayout from "./layouts/PanelLayout.jsx";
import Cartelera from "./pages/public/Cartelera.jsx";
import Login from "./pages/public/Login.jsx";
import Registro from "./pages/public/Registro.jsx";
import VerificarEmail from "./pages/public/VerificarEmail.jsx";
import Empresas from "./pages/admin/Empresas.jsx";
import EmpresaForm from "./pages/admin/EmpresaForm.jsx";
import Inicio from "./pages/panel/Inicio.jsx";
import NoEncontrada from "./pages/NoEncontrada.jsx";

// key distinta por id: al cambiar de empresa (o pasar a "nueva") el formulario arranca de cero
function EditarEmpresa() {
  const { id } = useParams();
  return <EmpresaForm key={id} />;
}

function App() {
  return (
    <Routes>
      {/* Público y cliente */}
      <Route element={<PublicLayout />}>
        <Route path="/" element={<Cartelera />} />
        <Route path="/login" element={<Login />} />
        <Route path="/registro" element={<Registro />} />
        <Route path="/verificar" element={<VerificarEmail />} />
      </Route>

      {/* Superadmin */}
      <Route element={<RutaProtegida roles={["superadmin"]} />}>
        <Route path="/admin" element={<AdminLayout />}>
          <Route index element={<Navigate to="empresas" replace />} />
          <Route path="empresas" element={<Empresas />} />
          <Route path="empresas/nueva" element={<EmpresaForm key="nueva" />} />
          <Route path="empresas/:id/editar" element={<EditarEmpresa />} />
          <Route path="*" element={<NoEncontrada />} />
        </Route>
      </Route>

      {/* Productora */}
      <Route element={<RutaProtegida roles={["empresa"]} />}>
        <Route path="/panel" element={<PanelLayout />}>
          <Route index element={<Inicio />} />
          <Route path="*" element={<NoEncontrada />} />
        </Route>
      </Route>

      <Route element={<PublicLayout />}>
        <Route path="*" element={<NoEncontrada />} />
      </Route>
    </Routes>
  );
}

export default App;
