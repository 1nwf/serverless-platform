job "redis" {
  type = "service"
  group "redis" {
    network {
      port "redis" {
        to     = 6379
        static = 6379
      }
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:latest"
        ports = ["redis"]
      }
    }
  }
}
