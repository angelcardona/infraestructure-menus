# Define la versión de Terraform y los proveedores requeridos
# El proveedor de postgresql se usa para interactuar con la DB local
terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.23.0"
    }
  }
}

# Define las variables que tu script de PowerShell pasará a Terraform
# No tienen un valor por defecto para que no queden guardadas en el código
variable "db_username" {
  type        = string
  description = "Usuario de la DB local para el aprovisionamiento."
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Contraseña de la DB local para el aprovisionamiento."
  sensitive   = true
}

# Define las credenciales estándar que la aplicación de Java usará
# Estos valores son fijos y consistentes para todo el equipo
locals {
  app_db_user = "dev_user"
  app_db_pass = "mysecretpassword123"
}

# Configura el proveedor de PostgreSQL para conectarse a la DB local
# Usa las variables que vienen del script de PowerShell
provider "postgresql" {
  host     = "localhost"
  port     = 5432
  username = var.db_username
  password = var.db_password
  sslmode  = "disable"
}

# Crea una nueva base de datos para el servicio monolítico de menús
resource "postgresql_database" "dev_db" {
  name = "menus_monolit_db"
}

# Crea un usuario estándar y una contraseña para que la aplicación Java se conecte
resource "postgresql_role" "dev_user" {
  name     = local.app_db_user
  login    = true
  password = local.app_db_pass
}

# Otorga todos los permisos sobre la nueva base de datos al usuario de la aplicación
resource "postgresql_grant" "dev_grant" {
  database    = postgresql_database.dev_db.name
  role        = postgresql_role.dev_user.name
  object_type = "database"
  privileges  = ["ALL"]
}

# Exporta la información de conexión estandarizada
# Tu script de PowerShell leerá esta salida para generar el archivo de propiedades
output "db_connection_info" {
  value = {
    user     = postgresql_role.dev_user.name
    password = local.app_db_pass
    db_name  = postgresql_database.dev_db.name
    host     = "localhost"
    port     = 5432
  }
}