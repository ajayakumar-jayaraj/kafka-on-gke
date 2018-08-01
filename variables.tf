variable "project" {
  type = "string"
}

variable "region" {
  type    = "string"
  default = "europe-west1"
}

variable "zone" {
  type    = "string"
  default = "europe-west1-b"
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