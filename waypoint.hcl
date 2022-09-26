project = "k8s-tetris"

pipeline "marathon" {
  step "up" {
    use "up" {
      prune = true
    }
  }
}

pipeline "up" {
  step "build" {
    use "build" {
    }
  }
  step "deploy" {
    use "deploy" {
    }
  }
  step "release" {
    use "release" {
    }
  }
}

pipeline "simple-nested" {
  step "here-we-go" {
    //image_url = "localhost:5000/waypoint-odr:latest"

    use "exec" {
      command = "echo"
      args    = ["lets try a nested pipeline"]
    }
  }

  step "deploy" {
    workspace = "test"

    pipeline "deploy" {
      step "build" {
        use "build" {
        }
      }
      step "deploy" {
        use "deploy" {
        }
      }
      step "release" {
        use "release" {
        }
      }
    }
  }

  step "deploy-prod" {
    workspace = "production"

    pipeline "deploy-prod" {
      step "build" {
        use "build" {
        }
      }
      step "deploy" {
        use "deploy" {
        }
      }
      step "release" {
        use "release" {
        }
      }
    }
  }
}

pipeline "release" {
  step "build" {
    use "build" {
    }
  }

  step "test" {
    workspace = "test"

    pipeline "test" {
      step "build" {
        use "build" {
        }
      }
      step "scan-then-sign" {
        //image_url = "localhost:5000/waypoint-odr:latest"

        use "exec" {
          command = "echo"
          args    = ["singing some artifacts!!"]
        }
      }

      step "deploy-test" {
        use "deploy" {
        }
      }

      step "healthz" {
        //image_url = "localhost:5000/waypoint-odr:latest"

        use "exec" {
          command = "curl"
          args    = ["-v", "http://192.168.147.119:3000"]
        }
      }
    }
  }

  step "on-to-prod" {
    //image_url = "localhost:5000/waypoint-odr:latest"

    use "exec" {
      command = "curl"
      args    = ["-v", "http://192.168.147.119:3000"]
    }
  }

  step "production" {
    workspace = "production"

    pipeline "prod" {
      step "build" {
        use "build" {
          // actually use docker-pull here
        }
      }

      step "deploy-prod" {
        use "deploy" {
        }
      }

      step "healthz" {
        //image_url = "localhost:5000/waypoint-odr:latest"

        use "exec" {
          command = "curl"
          args    = ["-v", "http://192.168.147.119:3000"]
        }
      }

      step "release-prod" {
        use "release" {
        }
      }
    }
  }

  step "notify-release" {
    //image_url = "localhost:5000/waypoint-odr:latest"

    use "exec" {
      command = "echo"
      args    = ["we released the app!!"]
    }
  }

}

runner {
  enabled = true

  data_source "git" {
    url  = "https://github.com/catsby/waypoint-tetris.git"
    path = ""
  }
}

app "tetris" {
  build {
    use "docker" {
    }
    # workspace "production" {
    #   use "docker-pull" {
    #     image = var.image
    #     tag   = var.tag
    #     auth {
    #       # header = base64encode("${var.registry_username}:${var.registry_password}")
    #       username = var.registry_username
    #       password = var.registry_password
    #     }
    #     # encoded_auth = base64encode(
    #     #   jsonencode({
    #     #     username = var.registry_username,
    #     #     password = var.registry_password
    #     #   })
    #     # )
    #   }
    # }

    registry {
      use "docker" {
        image    = var.image
        tag      = var.tag
        username = var.registry_username
        password = var.registry_password
        local    = var.registry_local
        # encoded_auth = base64encode(
        #   jsonencode({
        #     username = var.registry_username,
        #     password = var.registry_password
        #   })
        # )
      }
    }
  }

  deploy {
    use "kubernetes" {
      probe_path   = "/"
      image_secret = var.regcred_secret

      cpu {
        request = "250m"
        limit   = "500m"
      }

      memory {
        request = "64Mi"
        limit   = "128Mi"
      }

      autoscale {
        min_replicas = 2
        max_replicas = 5
        cpu_percent  = 50
      }
    }
  }

  release {
    use "kubernetes" {
      load_balancer = true
      port          = var.port
    }
  }
}

variable "image" {
  # free tier, old container registry
  #default     = "bcain.jfrog.io/default-docker-virtual/tetris"
  default     = "team-waypoint-dev-docker-local.artifactory.hashicorp.engineering/tetris"
  # default     = "ttl.sh/ctstetris"
  # default     = "catsby/tetris"
  type        = string
  description = "Image name for the built image in the Docker registry."
}

variable "tag" {
  default     = "latest"
  # default     = "1h"
  type        = string
  description = "Image tag for the image"
}

variable "registry_local" {
  default     = false
  type        = bool
  description = "Set to enable local or remote container registry pushing"
}

variable "registry_username" {
  default = dynamic("vault", {
    path = "secret/data/registry"
    key  = "/data/registry_username"
  })
  type        = string
  sensitive   = true
  description = "username for container registry"
}

variable "registry_password" {
  default = dynamic("vault", {
    path = "secret/data/registry"
    key  = "/data/registry_password"
  })
  type        = string
  sensitive   = true
  description = "password for registry" // don't hack me plz
}

variable "regcred_secret" {
  default     = "regcred"
  type        = string
  description = "The existing secret name inside Kubernetes for authenticating to the container registry"
}

variable "port" {
  type = number
  default = {
    "default"    = 3000
    "test" = 8080
    "production" = 9090
  }[workspace.name]
}
