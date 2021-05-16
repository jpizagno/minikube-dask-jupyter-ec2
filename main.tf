provider "aws" {
  version    = "~> 2.7"
  access_key = var.access_key # from variables.tf
  secret_key = var.secret_key # from variables.tf
  region     = var.region     # from variables.tf
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/27"

  tags = {
    Name = "minikube-dask-jupyter"
    billing = "minikube-dask-jupyter"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/28"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "minikube-dask-jupyter"
    billing = "minikube-dask-jupyter"
  }
}


resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "minikube-dask-jupyter"
    billing = "minikube-dask-jupyter"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }

  tags = {
    Name = "minikube-dask-jupyter"
    billing = "minikube-dask-jupyter"
  }
}

resource "aws_route_table_association" "public-rta" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id

}

resource "aws_security_group" "minikube-dask-jupyter" { 
  name        =   "minikube-dask-jupyter"
  description = "minikube-dask-jupyter"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "minikube-dask-jupyter"
    billing = "minikube-dask-jupyter"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.user_ip_address}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_instance" "ec2_minikube" {
  ami                    = "ami-0b1deee75235aa4bb"
  instance_type          = "t3a.xlarge"
  key_name               = var.key_name
  subnet_id                = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.minikube-dask-jupyter.id]
  associate_public_ip_address = true

  tags = {
    Name = "minikube-dask-jupyter"
    billing = "minikube-dask-jupyter"
  }

  root_block_device {
      volume_size = 20
  }

  # install docker, helm, minikube. then start minkube
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.ec2_minikube.public_ip
      agent       = false
      private_key = file("${var.key_path}${var.key_name}.pem")
    }
    inline = [
        "sudo apt  update",
        "sudo apt-get -y install     apt-transport-https     ca-certificates     curl     gnupg-agent     software-properties-common",
        "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
        "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
        "sudo apt -y update",
        "sudo apt -y install docker-ce",
        "sudo usermod -aG docker ubuntu",
        # cannot switch user, cannot run docker as root
        "sudo adduser --disabled-password --gecos \"\" yelper", 
        "sudo usermod -aG docker yelper",
        # install minikube
        "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb",
        "sudo dpkg -i minikube_latest_amd64.deb",
        # install kubectl
        "sudo snap install kubectl --classic",
        # install HELM
        "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -",
        "sudo apt-get install apt-transport-https --yes",
        "echo \"deb https://baltocdn.com/helm/stable/debian/ all main\" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list",
        "sudo apt -y update",
        "sudo apt-get -y install helm",
        # start minikube, as user yelper because we do not want to run docker as root
        "sudo -H -u yelper bash -c 'minikube start --driver=docker'",
    ]
  }
}

# this just waits 300 seconds for minikube to get up and running
resource "time_sleep" "wait_300_seconds" {
  depends_on = [aws_instance.ec2_minikube]

  create_duration = "300s"
}


resource "null_resource" "ec2_start_dask" {
  depends_on = [time_sleep.wait_300_seconds]

  # start help-dask, which starts DASK Pods (web UI, workers, and notebook)
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.ec2_minikube.public_ip
      agent       = false
      private_key = file("${var.key_path}${var.key_name}.pem")
    }
    inline = [
        # start minkube dashboard
        "sudo -H -u yelper bash -c 'nohup minikube dashboard > /tmp/dashboard.log 2>&1 &'",
        # install DASK
        "sudo -H -u yelper bash -c 'helm repo add dask https://helm.dask.org/'",
        "sudo -H -u yelper bash -c 'helm repo update'",
        "sudo -H -u yelper bash -c 'helm install \"dask\" dask/dask'",
    ]
  }
}

# this just waits 10 minutes for DASK to get up and running
resource "time_sleep" "wait_600_seconds_dask" {
  depends_on = [null_resource.ec2_start_dask]

  create_duration = "600s"
}

resource "null_resource" "ec2_port_forward_dask" {
  depends_on = [time_sleep.wait_600_seconds_dask]

  # start help-dask, which starts DASK Pods (web UI, workers, and notebook)
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.ec2_minikube.public_ip
      agent       = false
      private_key = file("${var.key_path}${var.key_name}.pem")
    }
    inline = [
        # run k8s port forwarding for DASK UI and JUPYTER                                                       
        "sudo -H -u yelper bash -c 'nohup kubectl port-forward --namespace default svc/dask-scheduler 7080:8786 > /tmp/DASK_SCHEDULER_PORT.log 2>&1 &'",     
        "sudo -H -u yelper bash -c 'nohup kubectl port-forward --namespace default svc/dask-scheduler 7081:80 > /tmp/DASK_SCHEDULER_UI_PORT.log 2>&1 &'",                                                             
        "sudo -H -u yelper bash -c 'nohup kubectl port-forward --namespace default svc/dask-jupyter 7082:80 > /tmp/JUPYTER_NOTEBOOK_PORT.log 2>&1 &'",
        "cat /tmp/JUPYTER_NOTEBOOK_PORT.log",
    ]
  }
}