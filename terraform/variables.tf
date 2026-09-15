variable "key_name" {
  description = "Nom de la key pair EC2 existante"
  type        = string
}
variable "my_ip" {
  description = "Mon IP publique pour restreindre l'accès SSH/monitoring"
  type        = string
}