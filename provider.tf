# provider
provider "aws" {
  region  = "ap-northeast-1"
}

provider http {
  version = "~> 1.1"
}

data http ifconfig {
  url = "http://ipv4.icanhazip.com/"
}
