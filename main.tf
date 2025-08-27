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

# Configura el proveedor de PostgreSQL para conectarse a la DB local
# Usa las variables que vienen del script de PowerShell
provider "postgresql" {
  host     = "localhost"
  port     = 5432
  username = var.db_username
  password = var.db_password
  sslmode  = "disable"
}

# Crea una nueva base de datos para el servicio de menús
resource "postgresql_database" "dev_db" {
  name = "menus_db"
}
