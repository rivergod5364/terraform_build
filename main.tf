resource "aws_vpc" "zabbix_vpc" {
  cidr_block                       = "10.10.0.0/16" # VPCに設定したいCIDRを指定
  enable_dns_support               = "true" # VPC内でDNSによる名前解決を有効化するかを指定
  enable_dns_hostnames             = "true" # VPC内インスタンスがDNSホスト名を取得するかを指定
  instance_tenancy                 = "default" # VPC内インスタンスのテナント属性を指定
  assign_generated_ipv6_cidr_block = "false" # IPv6を有効化するかを指定

  tags = {
    Name  = "zabbix_vpc"
  }
}

resource "aws_subnet" "zabbix_subnet_a" {
  vpc_id                          = aws_vpc.zabbix_vpc.id # VPCのIDを指定
  cidr_block                      = "10.10.1.0/24" # サブネットに設定したいCIDRを指定
  assign_ipv6_address_on_creation = "false" # IPv6を利用するかどうかを指定
  map_public_ip_on_launch         = "true" # VPC内インスタンスにパブリックIPアドレスを付与するかを指定
  availability_zone               = "ap-northeast-1a" # サブネットが稼働するAZを指定

  tags = {
    Name = "zabbix_subnet_1a"
  }
}
resource "aws_internet_gateway" "zabbix_igw" {
  vpc_id = aws_vpc.zabbix_vpc.id # VPCのIDを指定

  tags = {
    Name  = "zabbix_igw"
  }
}

resource "aws_route_table" "zabbix_rt" {
  vpc_id = aws_vpc.zabbix_vpc.id # VPCのIDを指定

  # 外部向け通信を可能にするためのルート設定
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zabbix_igw.id
  }

  tags = {
    Name  = "zabbix_rt"
  }
}
#VPCなど紐づけ設定
resource "aws_main_route_table_association" "zabbix_rt_vpc" {
  vpc_id         = aws_vpc.zabbix_vpc.id # 紐づけたいVPCのIDを指定
  route_table_id = aws_route_table.zabbix_rt.id # 紐付けたいルートテーブルのIDを指定
}

resource "aws_route_table_association" "zabbix_rt_subet_a" {
  subnet_id      = aws_subnet.zabbix_subnet_a.id # 紐づけたいサブネットのIDを指定
  route_table_id = aws_route_table.zabbix_rt.id # 紐付けたいルートテーブルのIDを指定
}

/*
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.3"
  name    = "vpc_apache"
  cidr    = "10.0.0.0/16"

  azs            = ["ap-northeast-1a"]
  public_subnets = ["10.0.1.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
*/

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.8.0"

  name        = "example"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = aws_vpc.zabbix_vpc.id

  ingress_cidr_blocks = [join("/", [chomp(data.http.ifconfig.body), "32"])]
  ingress_rules       = ["ssh-tcp", "http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "ssh_key_pair" {
  source                = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=master"
  namespace             = "test"
  stage                 = "dev"
  name                  = "apache"
  ssh_public_key_path   = "/secrets"
  generate_ssh_key      = "true"
  private_key_extension = ".pem"
  public_key_extension  = ".pub"
}

# EC2作成(public側)
resource "aws_instance" "ec2_apache_server" {
  ami                     = "ami-00c8dfcb0b542ee0c"
  instance_type           = "t2.micro"
  disable_api_termination = false
  key_name = module.ssh_key_pair.key_name
  vpc_security_group_ids  = [module.security_group.security_group_id]
  subnet_id               = aws_subnet.zabbix_subnet_a.id
 
  tags = {
    Name = "ec2_apache"
  }
}
/*
module "ec2_apache_server" {
  source         = "terraform-aws-modules/ec2-instance/aws"
  version        = "3.4.0"
  name           = "ec2_apache"

  ami                    = var.ami_redhat8
  instance_type          = var.ami_redhat8_instance_type
  key_name               = module.ssh_key_pair.key_name
  monitoring             = true
  vpc_security_group_ids = [module.security_group.security_group_id]
  subnet_id              = aws_subnet.zabbix_subnet_a.id

  root_block_device = [
    {
      delete_on_termination = "true"
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
*/