//Kubernetes Provider
provider "kubernetes" {
  //By Default works on Current Context
}

//Creating PVC for WordPress Pod
resource "kubernetes_persistent_volume_claim" "wp-pvc" {
  metadata {
    name   = "wp-pvc"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }

  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

//Creating PVC for MySQL Pod
resource "kubernetes_persistent_volume_claim" "MySqlPVC" {
  metadata {
    name   = "mysql-pvc"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }

  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

//Creating Deployment for WordPress
resource "kubernetes_deployment" "wp-dep" {
  metadata {
    name   = "wp-dep"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }
  depends_on = [
    kubernetes_deployment.MySql-dep, 
    kubernetes_service.MySqlService
  ]

  spec {
    replicas = 2
    selector {
      match_labels = {
        pod     = "wp"
        env     = "Production"
        Country = "India" 
        
      }
    }

    template {
      metadata {
        labels = {
          pod     = "wp"
          env     = "Production"
          Country = "India"  
        }
      }

      spec {
        volume {
          name = "wp-vol"
          persistent_volume_claim { 
            claim_name = "${kubernetes_persistent_volume_claim.wp-pvc.metadata.0.name}"
          }
        }

        container {
          image = "wordpress:4.8-apache"
          name  = "wp-container"

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "${kubernetes_service.MySqlService.metadata.0.name}"
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = "user"
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "resu"
          }
          env{
            name  = "WORDPRESS_DB_NAME"
            value = "wpdb"
          }
          env{
            name  = "WORDPRESS_TABLE_PREFIX"
            value = "wp_"
          }

          volume_mount {
              name       = "wp-vol"
              mount_path = "/var/www/html/"
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

//Creating Deployment for MySQL Pod
resource "kubernetes_deployment" "MySql-dep" {
  metadata {
    name   = "mysql-dep"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        pod     = "mysql"
        env     = "Production"
        Country = "India" 
      }
    }

    template {
      metadata {
        labels = {
          pod     = "mysql"
          env     = "Production"
          Country = "India" 
        }
      }

      spec {
        volume {
          name = "mysql-vol"
          persistent_volume_claim { 
            claim_name = "${kubernetes_persistent_volume_claim.MySqlPVC.metadata.0.name}"
          }
        }

        container {
          image = "mysql:5.6"
          name  = "mysql-container"

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "toor"
          }
          env {
            name  = "MYSQL_DATABASE"
            value = "wpdb"
          }
          env {
            name  = "MYSQL_USER"
            value = "user"
          }
          env{
            name  = "MYSQL_PASSWORD"
            value = "resu"
          }

          volume_mount {
              name       = "mysql-vol"
              mount_path = "/var/lib/mysql"
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

//Creating LoadBalancer Service for WordPress Pods
resource "kubernetes_service" "wpService" {
  metadata {
    name   = "wp-svc"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }  

  depends_on = [
    kubernetes_deployment.wp-dep
  ]

  spec {
    type     = "LoadBalancer"
    selector = {
      pod = "wp"
    }

    port {
      name = "wp-port"
      port = 80
    }
  }
}

//Creating ClusterIP service for MySQL Pods
resource "kubernetes_service" "MySqlService" {
  metadata {
    name   = "mysql-svc"
    labels = {
      env     = "Production"
      Country = "India" 
    }
  }  
  depends_on = [
    kubernetes_deployment.MySql-dep
  ]

  spec {
    selector = {
      pod = "mysql"
    }
  
    cluster_ip = "None"
    port {
      name = "mysql-port"
      port = 3306
    }
  }
}

//Wait For LoadBalancer to Register IPs
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on = [kubernetes_service.wpService]  
}

//Open Wordpress Site
resource "null_resource" "open_wp" {
  provisioner "local-exec" {
    command = "start chrome ${kubernetes_service.wpService.load_balancer_ingress.0.hostname}"
  }

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}