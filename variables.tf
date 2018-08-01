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

variable "num_kafka_brokers" {
  type    = "string"
  default = "3"
}
