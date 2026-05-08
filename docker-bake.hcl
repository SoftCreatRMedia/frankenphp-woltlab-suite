variable "IMAGE" {
  default = "ghcr.io/softcreatrmedia/frankenphp-woltlab-suite"
}

variable "DEBIAN_VERSION" {
  default = "trixie"
}

group "default" {
  targets = ["wsc62_php84", "wsc61_php83", "wsc60_php83"]
}

target "base" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
}

target "wsc62_php84" {
  inherits = ["base"]
  tags = [
    "${IMAGE}:6.2-php8.4",
    "${IMAGE}:6.2.3-php8.4",
  ]
  args = {
    PHP_VERSION = "8.4"
    DEBIAN_VERSION = "${DEBIAN_VERSION}"
    WSC_REF = "6.2.3"
  }
}

target "wsc61_php83" {
  inherits = ["base"]
  tags = [
    "${IMAGE}:6.1-php8.3",
    "${IMAGE}:6.1.19-php8.3",
  ]
  args = {
    PHP_VERSION = "8.3"
    DEBIAN_VERSION = "${DEBIAN_VERSION}"
    WSC_REF = "6.1.19"
  }
}

target "wsc60_php83" {
  inherits = ["base"]
  tags = [
    "${IMAGE}:6.0-php8.3",
    "${IMAGE}:6.0.25-php8.3",
  ]
  args = {
    PHP_VERSION = "8.3"
    DEBIAN_VERSION = "${DEBIAN_VERSION}"
    WSC_REF = "6.0.25"
  }
}
