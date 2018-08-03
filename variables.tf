variable "org_id" {
  type    = "string"
  default = ""
}

variable "folder_id" {
  type    = "string"
  default = ""
}

variable "billing_account" {
  type = "string"
}

variable "region" {
  type    = "string"
  default = "europe-west1"
}

variable "domain" {
  type = "string"
}

variable "zookeeper_replicas" {
  type    = "string"
  default = "3"
}

variable "zookeeper_disk_size" {
  type    = "string"
  default = "10G"
}

variable "kafka_replicas" {
  type    = "string"
  default = "3"
}

variable "kafka_disk_size" {
  type    = "string"
  default = "100G"
}

variable "source_ranges" {
  type    = "list"
  default = ["0.0.0.0/0"]
}
