# Este script automatiza la configuración completa del entorno de desarrollo para el proyecto de Google Menus.
# Asume que el desarrollador ha creado la carpeta "RexExperience" y ha clonado el repositorio
# "menus-infraestructure" dentro de ella.
# El script debe ser ejecutado desde la carpeta 'menus-infraestructure'.

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

# --- 1. Determinar la ruta base del proyecto y validar la estructura ---
Write-Separator
Write-Host "Iniciando la configuracion del entorno de desarrollo..." -ForegroundColor Cyan
Write-Separator

# La ruta base del proyecto (RexExperience) se determina moviendose un nivel hacia arriba desde el script
# e.g., si el script esta en .../RexExperience/menus-infraestructure,
# el $baseProjectDir sera .../RexExperience
$baseProjectDir = (Join-Path $PSScriptRoot "..")
$infraRepoDir = (Join-Path $baseProjectDir "menus-infraestructure")

# Validar que el script está en la ubicación correcta
if (-not (Test-Path -Path $baseProjectDir -PathType Container)) {
    Write-Error "El script no se esta ejecutando desde la ubicacion esperada."
    Write-Warning "Por favor, ejecute el script desde la carpeta 'menus-infraestructure'."
    exit 1
}

# --- 2. Validar dependencias (JDK, Git, y Terraform) ---
Write-Host "2. Validando dependencias..." -ForegroundColor Cyan

# Validar y establecer JAVA_HOME para una configuración unificada
Write-Info "Verificando JDK 21/17..."
$jdkPath = Get-ChildItem -Path "C:\Program Files\Java" -Filter "jdk-*" | Where-Object { $_.Name -match "jdk-(21|17)" } | Select-Object -First 1
if (-not $jdkPath) {
    Write-Error "JDK 21 o 17 no encontrado en 'C:\Program Files\Java'."
    Write-Warning "Por favor, instale la version correcta."
    Write-Warning "Instrucciones de descarga: https://www.oracle.com/java/technologies/downloads/"
    exit 1
}
$env:JAVA_HOME = $jdkPath.FullName
Write-Info "JDK 21/17 encontrado y JAVA_HOME establecido: $env:JAVA_HOME"

# Validar y establecer PGHOME para una configuración unificada
Write-Info "Verificando instalacion de PostgreSQL..."
$pgPath = Get-ChildItem -Path "C:\Program Files\PostgreSQL" -Filter "*" | Where-Object { $_.PSIsContainer } | Select-Object -Last 1
if (-not $pgPath) {
    Write-Error "PostgreSQL no encontrado en 'C:\Program Files\PostgreSQL'."
    Write-Warning "Por favor, instale PostgreSQL en su maquina."
    Write-Warning "Instrucciones de descarga: https://www.postgresql.org/download/windows/"
    exit 1
}
$env:PGHOME = (Join-Path $pgPath.FullName "bin")
Write-Info "PostgreSQL encontrado y PGHOME establecido: $env:PGHOME"

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

# --- 4. Ejecutar Terraform para aprovisionar la base de datos menus_db ---
Write-Host "4. Ejecutando Terraform..." -ForegroundColor Cyan
# La ruta a Terraform es el directorio principal del repositorio de infraestructura
$terraformPath = $infraRepoDir

if (-not (Test-Path -Path $terraformPath -PathType Container)) {
    Write-Error "El directorio de Terraform no existe en la ruta esperada: $terraformPath"
    Write-Warning "Esto significa que el repositorio de infraestructura no contiene la configuracion de Terraform."
    exit 1
}

try {
    # Cambiar al directorio de Terraform
    Set-Location -Path $terraformPath

    # Establecer las variables de entorno para que Terraform las lea
    $Env:TF_VAR_db_username = $PostgresUser
    $Env:TF_VAR_db_password = $PostgresPassword_Plain

    Write-Info "Inicializando Terraform..."
    & terraform init -input=false -backend=false

    Write-Info "Verificando si la base de datos 'menus_db' ya existe..."
    $dbExists = & terraform state list | Select-String -Pattern "postgresql_database.dev_db" -Quiet
    if ($dbExists) {
        Write-Warning "La base de datos 'menus_db' ya existe. Se omite la creacion."
    } else {
        Write-Info "Aplicando configuracion de infraestructura. Esto creara la DB 'menus_db'..."
        & terraform apply -auto-approve -input=false
    }

    # Restaurar la ubicacion actual del script
    Set-Location -Path $PSScriptRoot

} catch {
    Write-Error "Error al ejecutar Terraform. Revise el mensaje anterior para mas detalles."
    exit 1
}
Write-Separator

# --- 5. Persistir las credenciales de la base de datos en un archivo .env local ---
Write-Host "5. Persistiendo credenciales de DB en un archivo .env..." -ForegroundColor Cyan
try {
    $envFilePath = Join-Path $baseProjectDir ".env"
    "DB_USERNAME=$PostgresUser" | Out-File -FilePath $envFilePath -Encoding utf8
    "DB_PASSWORD=$PostgresPassword_Plain" | Out-File -FilePath $envFilePath -Encoding utf8 -Append
    "DB_NAME=menus_db" | Out-File -FilePath $envFilePath -Encoding utf8 -Append
    
    Write-Info "Archivo .env creado en el directorio principal del proyecto."
    Write-Warning "AVISO: Asegúrese de que su aplicación está configurada para cargar variables de entorno desde el archivo .env."
} catch {
    Write-Error "Error al crear el archivo .env. Por favor, verifique sus permisos de escritura."
    exit 1
}
Write-Separator

# --- 6. Clonar repositorios de servicios (si no existen) ---
Write-Host "6. Clonando repositorios de servicios..." -ForegroundColor Cyan

# Lista de servicios a clonar
$services = @("api-gateway", "menu-ai-agent", "menu-service", "menus-eureka")

foreach ($service in $services) {
    $servicePath = (Join-Path $baseProjectDir $service)
    if (-not (Test-Path -Path $servicePath -PathType Container)) {
        Write-Info "Clonando $service..."
        # Reemplaza esta URL con la URL real de tu repositorio
        git clone "https://example.com/repos/$service.git" "$servicePath"
    } else {
        Write-Warning "El repositorio $service ya existe. Se omite la clonacion."
    }
}
Write-Separator

# --- 7. Finalizar ---
Write-Host "✅ ¡Configuracion del entorno completada!" -ForegroundColor Green
Write-Info "Tu entorno de desarrollo está listo."
Write-Info "La base de datos 'menus_db' ha sido creada."
Write-Info "Los repositorios de los servicios han sido clonados."
Write-Info "Las credenciales de la base de datos se han guardado en un archivo .env local."
Write-Info "Ahora puedes navegar a la carpeta de tu servicio y comenzar a desarrollar."
Write-Separator
