locals {
  project_services = [
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
  ]

  service_account_iam_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
    "roles/cloudtrace.agent",
  ]

  name = "kafka"

  kafka_replicas             = "${max(var.kafka_replicas, 3)}"
  zookeeper_replicas         = "${min(local.kafka_replicas, max(var.zookeeper_replicas, 1))}"
  number_of_nodes_per_region = "${local.kafka_replicas / 3 + (local.kafka_replicas % 3 == 0 ? 0 : 1)}"
}

resource "random_id" "random" {
  prefix      = "kafka-"
  byte_length = "8"
}

# Create the project
resource "google_project" "default" {
  name                = "${random_id.random.hex}"
  project_id          = "${random_id.random.hex}"
  org_id              = "${var.org_id}"
  folder_id           = "${var.folder_id}"
  billing_account     = "${var.billing_account}"
  auto_create_network = false
}

# Enable required services on the project
resource "google_project_service" "service" {
  count              = "${length(local.project_services)}"
  project            = "${google_project.default.id}"
  service            = "${element(local.project_services, count.index)}"
  disable_on_destroy = false
}

/* = VPC ====================================================== */

resource "google_compute_network" "default" {
  project                 = "${google_project.default.id}"
  name                    = "${local.name}"
  auto_create_subnetworks = "false"

  depends_on = ["google_project_service.service"]
}

resource "google_compute_subnetwork" "default" {
  project       = "${google_project.default.id}"
  name          = "${local.name}"
  network       = "${google_compute_network.default.self_link}"
  region        = "${var.region}"
  ip_cidr_range = "10.0.4.0/22"

  depends_on = ["google_project_service.service"]
}

resource "google_compute_address" "default" {
  project = "${google_project.default.id}"
  region  = "${var.region}"
  count   = "${local.kafka_replicas}"
  name    = "kafka-${count.index}"

  depends_on = ["google_project_service.service"]
}

/* = Service Accounts ========================================= */

resource "google_service_account" "default" {
  project      = "${google_project.default.id}"
  account_id   = "${local.name}-gke"
  display_name = "${local.name} gke service account"
}

resource "google_project_iam_member" "default" {
  project = "${google_project.default.id}"
  count   = "${length(local.service_account_iam_roles)}"
  role    = "${element(local.service_account_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.default.email}"
}

/* = Regional Kubernetes Cluster =*/

data "google_compute_zones" "default" {
  project = "${google_project.default.id}"
  region  = "${var.region}"
}

data "google_container_engine_versions" "default" {
  project = "${google_project.default.id}"
  zone    = "${data.google_compute_zones.default.names.0}"
}

resource "google_container_cluster" "default" {
  project = "${google_project.default.id}"
  name    = "${local.name}"
  region  = "${var.region}"

  network    = "${google_compute_network.default.name}"
  subnetwork = "${google_compute_subnetwork.default.name}"

  min_master_version = "${data.google_container_engine_versions.default.latest_master_version}"

  lifecycle {
    ignore_changes = [
      "node_pool",
    ]
  }

  node_pool {
    name = "default-pool"
  }

  remove_default_node_pool = true

  depends_on = ["google_project_service.service"]
}

resource "google_container_node_pool" "default" {
  project    = "${google_project.default.id}"
  cluster    = "${google_container_cluster.default.name}"
  name       = "broker"
  region     = "${var.region}"
  node_count = "${local.number_of_nodes_per_region}"

  node_config {
    machine_type = "n1-standard-4"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/trace.append",
    ]

    service_account = "${google_service_account.default.email}"
  }

  depends_on = ["google_project_service.service"]
}

/* = Helm Charts == */

resource "null_resource" "apply" {
  triggers {
    host                   = "${md5(google_container_cluster.default.endpoint)}"
    username               = "${md5(google_container_cluster.default.master_auth.0.username)}"
    password               = "${md5(google_container_cluster.default.master_auth.0.password)}"
    client_certificate     = "${md5(google_container_cluster.default.master_auth.0.client_certificate)}"
    client_key             = "${md5(google_container_cluster.default.master_auth.0.client_key)}"
    cluster_ca_certificate = "${md5(google_container_cluster.default.master_auth.0.cluster_ca_certificate)}"
  }

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.default.name}" --zone="${google_container_cluster.default.zone}" --project="${google_container_cluster.default.project}"
kubectl config set-context "gke_${google_container_cluster.default.project}_${google_container_cluster.default.zone}_${google_container_cluster.default.name}"

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
EOF
  }

  depends_on = ["google_container_cluster.default", "google_container_node_pool.default"]
}

provider "helm" {
  service_account = "tiller"

  kubernetes {
    host                   = "${google_container_cluster.default.endpoint}"
    username               = "${google_container_cluster.default.master_auth.0.username}"
    password               = "${google_container_cluster.default.master_auth.0.password}"
    client_certificate     = "${base64decode(google_container_cluster.default.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.default.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.default.master_auth.0.cluster_ca_certificate)}"
  }
}

resource "helm_release" "default" {
  name  = "kafka"
  chart = "${path.module}/chart"

  values = [<<EOF
domain: ${var.domain}
addresses: ${jsonencode(sort(google_compute_address.default.*.address))}
sourceRanges: ${jsonencode(sort(var.source_ranges))}
zookeeper:
  replicas: ${local.zookeeper_replicas}
  disk:
    size: ${var.zookeeper_disk_size}
kafka:
  replicas: ${local.kafka_replicas}
  disk:
    size: ${var.kafka_disk_size}
EOF
  ]

  depends_on = ["google_container_node_pool.default", "null_resource.apply"]
}
