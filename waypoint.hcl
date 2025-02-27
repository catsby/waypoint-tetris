project = "k8s-tetris"

app "tetris" {
  build {
    use "docker" {
    }
    workspace "production" {
      use "docker-pull" {
        image = var.image
        tag   = var.tag
        disable_entrypoint = var.disable_ceb
        encoded_auth = base64encode(
          jsonencode({
            username = var.registry_username,
            password = var.registry_password
          })
        )
      }
    }

    registry {
      use "docker" {
        image    = var.push_image
        tag      = var.tag
        username = var.push_registry_username
        password = var.push_registry_password
        local    = var.registry_local
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
        min_replicas = 1
        max_replicas = 2
        cpu_percent  = 50
      }
    }
  }

  release {
    use "kubernetes" {
      load_balancer = true
      port          = var.port
    }
    workspace "production" {
      use "kubernetes" {
        load_balancer = true
        port          = "3030"
      }
    }
  }
}

variable "disable_ceb" {
  default     = false
  type        = bool
  description = "disable ceb or not"
}

variable "image" {
  default     = "team-waypoint-dev-docker-local.artifactory.hashicorp.engineering/tetris"
  type        = string
  description = "Image name for the built image in the Docker registry."
}

variable "push_image" {
  default     = "registry.hub.docker.com/catsby/tetris"
  type        = string
  description = "Image name for the built image in the Docker registry."
}

variable "tag" {
  default     = "latest"
  type        = string
  description = "Image tag for the image"
}

variable "registry_local" {
  default     = false
  type        = bool
  description = "Set to enable local or remote container registry pushing"
}

variable "registry_username" {
  default = "test"
  type        = string
  sensitive   = true
  description = "username for container registry"
}

variable "registry_password" {
  default = "test"
  type        = string
  sensitive   = true
  description = "password for registry"
}

variable "push_registry_username" {
  default = "catsby"
  type        = string
  sensitive   = true
  description = "username for container push registry"
}

variable "push_registry_password" {
  default = "nope"
  type        = string
  sensitive   = true
  description = "password for push registry"
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
    "production" = 3030
  }[workspace.name]
}

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

pipeline "single" {
  step "here-we-go" {
    image_url = "curlimages/curl:latest"

    use "exec" {
      command = "echo"
      args    = ["lets try a nested pipeline"]
    }
  }

  step "healthz" {
    image_url = "curlimages/curl:latest"

    use "exec" {
      command = "curl"
      # args    = ["-I", "192.168.147.119:3030"]
      args    = ["-I", "192.168.147.119:3030"]
    }
  }
}

pipeline "multi-deploy" {
  step "begin-release" {
    image_url = "curlimages/curl:latest"

    use "exec" {
      command = "echo"
      args    = ["new build begining..."]
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

  step "notify-release" {
    image_url = "curlimages/curl:latest"

    use "exec" {
      command = "echo"
      args    = ["Test and Production updated!"]
    }
  }
}

pipeline "prod-promote" {
  step "build" {
    use "build" {
    }
  }

  step "promote" {
    workspace = "production"

    pipeline "deploy-prod" {
      step "build" {
        use "build" {
        }
      }
      step "scan-then-sign" {
        image_url = "curlimages/curl:latest"

        use "exec" {
          command = "echo"
          args    = ["singing some artifacts!!"]
        }
      }

      step "deploy" {
        use "deploy" {
        }
      }

      step "healthz" {
        image_url = "curlimages/curl:latest"

        use "exec" {
          command = "curl"
          args    = ["-v", "localhost:3030"]
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
        image_url = "curlimages/curl:latest"

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
        image_url = "curlimages/curl:latest"

        use "exec" {
          command = "curl"
          args    = ["-v", "localhost:3000"]
        }
      }
    }
  }

  step "on-to-prod" {
    image_url = "curlimages/curl:latest"

    use "exec" {
      command = "curl"
      args    = ["-v", "localhost:3000"]
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
        image_url = "curlimages/curl:latest"

        use "exec" {
          command = "curl"
          args    = ["-v", "localhost:3000"]
        }
      }

      step "release-prod" {
        use "release" {
        }
      }
    }
  }

  step "notify-release" {
    image_url = "curlimages/curl:latest"

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
