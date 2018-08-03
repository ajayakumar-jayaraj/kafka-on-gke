# Kafka-as-a-Service on GKE with Terraform

This tutorial walks through provisioning an [Apache Kafka][vault] cluster on [Google Kubernetes Engine][gke] using [HashiCorp Terraform][terraform] as the provisioning tool.

## Feature Highlights

- **High Availability** - The Kafka cluster is deployed in a [Regional Cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/regional-clusters), improving availability and resilience by distributing Kafka borkers across multiple zones within a region

- **Full Isolation** - The Kafka cluster is provisioned in it's own Kubernetes cluster in a dedicated GCP project that is provisioned dynamically at runtime. Clients connect to Kafka using **only** the load balancers and Kafka is treated as a managed external service.

## Tutorial

1. Download and install [Terraform][terraform]

1. Download and install [Terraform Provider for Helm](https://github.com/mcuadros/terraform-provider-helm)

1. Download, install, and configure the [Google Cloud SDK][sdk]. You will need to configure your default application credentials so Terraform can run. It will run against your default project, but all resources are created in the (new) project that it creates.

1. Install the [kubernetes CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (aka `kubectl`)

1. Run Terraform:

    ```
    $ cd terraform/
    $ terraform init
    $ terraform apply -var 'domain=example.com'
    ```

    This operation will take some time as it:

    1. Creates a new project
    1. Enables the required services on that project
    1. Creates a VPC network and subnetwork
    1. Creates a service account with the most restrictive permissions required
    1. Creates a GKE cluster with the configured service account attached
    1. Creates a public IP for each broker replica
    1. Configures your local system to talk to the GKE cluster by getting the cluster credentials and kubernetes context
    1. Submits the StatefulSets and Services to the Kubernetes API using a Helm chart
    
1. Configure a DNS entry for each Kafka broker by adding an A record for each subdomain `kafka-X.<your domain>` (eg `kafka-0.example.com, kafka-1.example.com, ...`). 

    The required IP address are available as Terraform output 
    
    ```
    $ terraform output
    addresses = [
        130.211.59.144,
        35.195.190.20,
        35.233.24.182
    ]
    $    
    ```
    
## Interact with Kafka using [kafkacat](https://github.com/edenhill/kafkacat)

In metadata list mode (-L), kafkacat displays the current state of the Kafka cluster and its topics, partitions, replicas and in-sync replicas (ISR).

    
```
$ kafkacat -L -b kafka-0.example.com
Metadata for all topics (from broker 0: kafka-0.example.com:9092/0):
 3 brokers:
  broker 2 at kafka-2.example.com:9092
  broker 1 at kafka-1.example.com:9092
  broker 0 at kafka-0.example.com:9092
 1 topics:
  topic "__confluent.support.metrics" with 1 partitions:
    partition 0, leader 0, replicas: 0, isrs: 0
$
```

## Cleaning Up

```
$ terraform destroy
```

Note that this can sometimes fail. Re-run it and it should succeed. If things get into a bad state, you can always just delete the project.

## Security

At this moment no security considerations are taken into account at all. (so don't use this setup for a production environment ;-) )

By default this tutorial will create a Kafka cluster that is publicly accesible for everyone, but you can specify the IP ranges that are allowed to access the Kafka Cluster. 
This variable takes a list of IP CIDR ranges, which Kubernetes will use to configure firewall exceptions.

Further security measures, such as encryption, authentication and authorization, are left as exercise an further improvement. (pull requests are always welcome)

[gcs]: https://cloud.google.com/storage
[gke]: https://cloud.google.com/kubernetes-engine
[sdk]: https://cloud.google.com/sdk
[terraform]: https://www.terraform.io