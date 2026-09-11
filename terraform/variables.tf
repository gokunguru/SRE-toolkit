variable "ami_id" {
  description = "AMI Ubuntu 22.04 pour eu-west-3"
  type        = string
  default     = "ami-0f14005c691fc0d7f"  # vérifie l'ID actuel dans la console EC2
}

variable "key_name" {
  description = "Nom de la key pair EC2 existante"
  type        = string
}