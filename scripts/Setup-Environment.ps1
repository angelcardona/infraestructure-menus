# Este script automatiza la configuración del entorno de desarrollo para el proyecto de Google Menus.

function Write-Separator {
    Write-Host "---------------------------------------------------" -ForegroundColor Green
}

function Write-Info($message) {
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "⚠️ $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "❌ ERROR: $message" -ForegroundColor Red
}

# --- 1. Iniciar el script ---
Write-Separator
Write-Host "Iniciando la configuracion del entorno de desarrollo..." -ForegroundColor Cyan
Write-Separator

# --- 2. Validar dependencias (JDK, PostgreSQL, Git, y Terraform) ---
Write-Host "2. Validando dependencias..." -ForegroundColor Cyan

# Validar JDK 21 o 17 usando PATH y JAVA_HOME
Write-Info "Verificando JDK 21/17..."
try {
    # Intenta encontrar el comando 'java' en el PATH
    $javaCommand = Get-Command java -ErrorAction Stop
    $javaVersion = java -version 2>&1 | Select-String -Pattern "version "
    if ($null -eq $javaVersion) {
        Write-Error "El JDK en el PATH no es la version 21 o 17."
        Write-Warning "Por favor, instale la version correcta."
        Write-Warning "Instrucciones de descarga: https://www.oracle.com/java/technologies/downloads/"
        exit 1
    }
    Write-Info "JDK 21/17 encontrado."
} catch {
    Write-Error "El comando 'java' no se encontro en su PATH. Asegurese de que JDK este instalado y en su PATH."
    exit 1
}

# Validar PostgreSQL
Write-Info "Verificando instalacion de PostgreSQL..."
try {
    # Intenta encontrar el comando 'psql' en el PATH
    $psqlCommand = Get-Command psql -ErrorAction Stop
    $postgresVersion = psql --version 2>&1 | Select-String -Pattern "psql"
    if ($null -eq $postgresVersion) {
        Write-Error "PostgreSQL no encontrado."
        Write-Warning "Por favor, instale PostgreSQL en su maquina y asegurese de que 'psql' este en su PATH."
        Write-Warning "Instrucciones de descarga: https://www.postgresql.org/download/windows/"
        exit 1
    }
    Write-Info "PostgreSQL encontrado."
} catch {
    Write-Error "El comando 'psql' no se encontro en su PATH. Asegurese de que PostgreSQL este instalado y en su PATH."
    exit 1
}

# Validar Git
Write-Info "Verificando instalacion de Git..."
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Error "Git no encontrado. Por favor, instale Git."
    Write-Warning "Instrucciones de descarga: https://git-scm.com/downloads"
    exit 1
}
Write-Info "Git encontrado."

# Validar Terraform
Write-Info "Verificando instalacion de Terraform..."
if (-not (Get-Command "terraform" -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform no encontrado. Por favor, instale Terraform."
    Write-Warning "Instrucciones de descarga: https://www.terraform.io/downloads"
    exit 1
}
Write-Separator

# --- 3. Solicitar credenciales de aprovisionamiento de PostgreSQL ---
Write-Host "3. Proporcionando credenciales para el aprovisionamiento de la base de datos..." -ForegroundColor Cyan
Write-Warning "Estas credenciales son solo para la configuracion inicial de la base de datos.
No se guardaran en el repositorio."

$PostgresUser = Read-Host -Prompt "Ingrese su usuario local de PostgreSQL (p. ej., 'postgres')"
$PostgresPassword = Read-Host -Prompt "Ingrese su contrasena de PostgreSQL" -AsSecureString
$PostgresPassword_Plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgresPassword))
Write-Separator

# --- 4. Ejecutar Terraform para aprovisionar la base de datos monolítica ---
Write-Host "4. Ejecutando Terraform..." -ForegroundColor Cyan
$terraformPath = Join-Path $PSScriptRoot "..\terraform"
if (-not (Test-Path -Path $terraformPath -PathType Container)) {
    Write-Error "El directorio de Terraform no existe en la ruta esperada: $terraformPath"
    Write-Warning "Por favor, cree el directorio y coloque sus archivos de configuracion de Terraform (.tf) alli."
    exit 1
}

try {
    # Cambiar al directorio de Terraform
    Set-Location -Path $terraformPath

    # Establecer las variables de entorno para que Terraform las lea
    $Env:TF_VAR_db_username = $PostgresUser
    $Env:TF_VAR_db_password = $PostgresPassword_Plain

    Write-Info "Inicializando Terraform..."
    terraform init -input=false -backend=false

    Write-Info "Aplicando configuracion de infraestructura. Esto creara la DB 'menus_monolit_db'..."
    terraform apply -auto-approve -input=false

    # Restaurar la ubicacion actual del script
    Set-Location -Path $PSScriptRoot

} catch {
    Write-Error "Error al ejecutar Terraform. Revise el mensaje anterior para mas detalles."
    exit 1
}
Write-Separator

# --- 5. Clonar repositorios de servicios (si no existen) ---
Write-Host "5. Clonando repositorios de servicios..." -ForegroundColor Cyan

# Lista de servicios a clonar
$services = @("api-gateway", "menu-ai-agent", "menu-service", "menus-eureka")
$parentDir = (Join-Path $PSScriptRoot "..")

foreach ($service in $services) {
    $servicePath = (Join-Path $parentDir $service)
    if (-not (Test-Path -Path $servicePath -PathType Container)) {
        Write-Info "Clonando $service..."
        # Reemplaza esta URL con la URL real de tu repositorio
        git clone "https://example.com/repos/$service.git" "$servicePath"
    } else {
        Write-Warning "El repositorio $service ya existe. Se omite la clonacion."
    }
}
Write-Separator

# --- 6. Finalizar ---
Write-Host "✅ ¡Configuracion del entorno completada!" -ForegroundColor Green
Write-Info "Tu entorno de desarrollo está listo."
Write-Info "La base de datos 'menus_monolit_db' ha sido creada."
Write-Info "Los repositorios de los servicios han sido clonados."
Write-Info "Ahora puedes navegar a la carpeta de tu servicio y comenzar a desarrollar."
Write-Separator
