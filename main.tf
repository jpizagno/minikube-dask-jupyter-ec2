provider "aws" {
  version    = "~> 2.7"
  access_key = var.access_key # from variables.tf
  secret_key = var.secret_key # from variables.tf
  region     = var.region     # from variables.tf
}

resource "aws_security_group" "minikube-dask-jupyter" { 
  name        =   "minikube-dask-jupyter"
  description = "minikube-dask-jupyter github branch ${var.github_branch}"
  vpc_id      = var.vpc_id

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
  vpc_security_group_ids = [aws_security_group.minikube-dask-jupyter.id]

  root_block_device {
      volume_size = 20
  }

  # install docker, helm, minikube. then start minkube
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.ec2_minikube_started.public_ip
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
        # start minikube 
        "nohup minikube start --driver=docker > minikube.log 2>&1 &",
    ]
  }
}

# this just waits 300 seconds for minikube to get up and running
resource "time_sleep" "wait_300_seconds" {
  depends_on = [aws_instance.ec2_minikube]

  create_duration = "300s"
}


resource "null_resource" "ec2_minikube_command_runner" {
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
        "nohup minikube dashboard > dashboard.log 2>&1 &",
        # install DASK
        "helm repo add dask https://helm.dask.org/",
        "helm repo update",
        "helm install \"dask\" dask/dask",
        # run k8s port forwarding for DASK UI and JUPYTER
        "export DASK_SCHEDULER=\"127.0.0.1\"",                                                             
        "export DASK_SCHEDULER_UI_IP=\"127.0.0.1\"",                                                       
        "export DASK_SCHEDULER_PORT=7080",                                                               
        "export DASK_SCHEDULER_UI_PORT=7081",                                                           
        "nohup kubectl port-forward --namespace default svc/dask-scheduler $DASK_SCHEDULER_PORT:8786 > DASK_SCHEDULER_PORT.log 2>&1 &",     
        "nohup kubectl port-forward --namespace default svc/dask-scheduler $DASK_SCHEDULER_UI_PORT:80 > DASK_SCHEDULER_UI_PORT.log 2>&1 &",  
        "export JUPYTER_NOTEBOOK_IP=\"127.0.0.1\"",                                                       
        "export JUPYTER_NOTEBOOK_PORT=7082",                                                            
        "nohup kubectl port-forward --namespace default svc/dask-jupyter $JUPYTER_NOTEBOOK_PORT:80 > JUPYTER_NOTEBOOK_PORT.log 2>&1 &",
    ]
  }
}