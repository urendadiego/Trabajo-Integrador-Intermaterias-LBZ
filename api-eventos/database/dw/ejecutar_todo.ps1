# ============================================================================
# Arma las dos bases del coloquio en el PostgreSQL instalado en Windows:
#   backstage     (operativa: scripts 01 a 12 de database/ + datos ficticios)
#   backstage_dw  (data warehouse: conexión, tablas, procedimiento, carga y verificación)
#
# Uso (desde PowerShell, en esta carpeta):
#   .\ejecutar_todo.ps1                   pide la contraseña del usuario postgres
#   .\ejecutar_todo.ps1 -Recrear          borra las dos bases si ya existen y empieza de cero
#
# Si Windows no deja ejecutar scripts:
#   powershell -ExecutionPolicy Bypass -File .\ejecutar_todo.ps1
# ============================================================================
param(
    [string]$Clave,
    [switch]$Recrear,
    [string]$Version = '18'
)

$ErrorActionPreference = 'Stop'
$psql = "C:\Program Files\PostgreSQL\$Version\bin\psql.exe"
if (-not (Test-Path $psql)) { throw "No encuentro psql en $psql. Pasá -Version con tu versión de PostgreSQL." }

$dw        = $PSScriptRoot
$operativa = Split-Path $dw -Parent

# ─── Contraseña: parámetro, variable PGPASSWORD, pgpass.conf o se pide ──────
if (-not $Clave) { $Clave = $env:PGPASSWORD }
if (-not $Clave) {
    $pgpass = Join-Path $env:APPDATA 'postgresql\pgpass.conf'
    if (Test-Path $pgpass) {
        $linea = Get-Content $pgpass | Where-Object { $_ -match '^(localhost|127\.0\.0\.1|\*):(5432|\*):[^:]*:postgres:' } | Select-Object -First 1
        if ($linea) { $Clave = ($linea -split ':', 5)[4] }
    }
}
if (-not $Clave) {
    $segura = Read-Host 'Contraseña del usuario postgres' -AsSecureString
    $Clave  = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura))
}
$env:PGPASSWORD       = $Clave
$env:PGCLIENTENCODING = 'UTF8'
# Oculta los NOTICE ("no existe la tabla…, omitiendo"): son normales, pero PowerShell los muestra como error
$env:PGOPTIONS        = '-c client_min_messages=warning'

function Invoke-Psql([string]$Base, [string[]]$Argumentos) {
    & $psql -h localhost -p 5432 -U postgres -d $Base -X -q -v ON_ERROR_STOP=1 @Argumentos
    if ($LASTEXITCODE -ne 0) { throw "Falló psql en la base $Base ($($Argumentos -join ' '))" }
}
function Invoke-Archivo([string]$Base, [string]$Archivo) {
    Write-Host "  -> $(Split-Path $Archivo -Leaf)  [$Base]" -ForegroundColor DarkGray
    Invoke-Psql $Base @('-f', $Archivo)
}
function Test-Base([string]$Nombre) {
    $r = & $psql -h localhost -p 5432 -U postgres -d postgres -X -tA -c "SELECT 1 FROM pg_database WHERE datname = '$Nombre'"
    if ($LASTEXITCODE -ne 0) { throw 'No me pude conectar al servidor. ¿Está bien la contraseña?' }
    return ($r -eq '1')
}

# ─── 0. Bases ───────────────────────────────────────────────────────────────
Write-Host "`n0. Bases de datos" -ForegroundColor Cyan
foreach ($base in 'backstage_dw', 'backstage') {
    if (Test-Base $base) {
        if (-not $Recrear) { throw "La base $base ya existe. Corré con -Recrear para borrarla y empezar de cero." }
        Write-Host "  -> borro $base"
        Invoke-Psql 'postgres' @('-c', "DROP DATABASE $base WITH (FORCE)")
    }
}
Invoke-Psql 'postgres' @('-c', "CREATE DATABASE backstage ENCODING 'UTF8'")

# ─── 1. Operativa ───────────────────────────────────────────────────────────
Write-Host "`n1. Base operativa (backstage)" -ForegroundColor Cyan
Get-ChildItem $operativa -Filter '*.sql' | Where-Object { $_.Name -match '^(0[1-9]|1[0-2])_' } | Sort-Object Name |
    ForEach-Object { Invoke-Archivo 'backstage' $_.FullName }

Write-Host "`n2. Datos ficticios" -ForegroundColor Cyan
Invoke-Archivo 'backstage' (Join-Path $dw '01_datos_ficticios.sql')

# ─── 2. Data warehouse ──────────────────────────────────────────────────────
Write-Host "`n3. Base del data warehouse (backstage_dw)" -ForegroundColor Cyan
Invoke-Archivo 'postgres' (Join-Path $dw '02_crear_base_dw.sql')

# La contraseña va en un archivo temporal (no se guarda en el repo) y se borra enseguida
$tmp = Join-Path $env:TEMP 'backstage_dw_03.sql'
$claveSql = $Clave.Replace("'", "''")
$texto = (Get-Content (Join-Path $dw '03_conexion_origen.sql') -Raw -Encoding UTF8).Replace('CAMBIAR_POR_TU_CLAVE', $claveSql)
[IO.File]::WriteAllText($tmp, $texto, (New-Object Text.UTF8Encoding $false))   # UTF-8 sin BOM: psql no lo entiende
try     { Invoke-Archivo 'backstage_dw' $tmp }
finally { Remove-Item $tmp -ErrorAction SilentlyContinue }

Invoke-Archivo 'backstage_dw' (Join-Path $dw '04_tablas_dw.sql')
Invoke-Archivo 'backstage_dw' (Join-Path $dw '05_procedimiento_carga.sql')

Write-Host "`n4. Carga: CALL cargar_dw()" -ForegroundColor Cyan
Invoke-Psql 'backstage_dw' @('-c', 'CALL cargar_dw();')

Write-Host "`n5. Verificación (las diferencias tienen que dar 0)" -ForegroundColor Cyan
Invoke-Archivo 'backstage_dw' (Join-Path $dw '06_verificacion.sql')

Write-Host "`nListo. Las consultas están en 07_consultas.sql: abrilo en pgAdmin sobre backstage_dw." -ForegroundColor Green
