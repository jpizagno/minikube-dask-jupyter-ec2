 ######################################
 # install minikube
 # https://minikube.sigs.k8s.io/docs/start/
 ######################################
 sudo apt  update
 sudo apt -y install docker.io 
 sudo apt -y  install  containerd runc
 sudo apt-get -y install     apt-transport-https     ca-certificates     curl     gnupg-agent     software-properties-common
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
 sudo apt-get -y update
 sudo apt-get -y install  docker-ce-cli containerd.io
 apt-cache madison docker-ce
 sudo usermod -aG docker ubuntu
 sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
 sudo chmod +x /usr/local/bin/docker-compose
 curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
 sudo dpkg -i minikube_latest_amd64.deb
 minikube start --driver=docker

######################################
# install kubectl
######################################
 sudo snap install kubectl --classic
 kubectl get po -A


######################################
# install HELM
# https://helm.sh/docs/intro/install/
######################################
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

######################################
# install DASK
# https://www.dabbleofdevops.com/blog/deploy-and-scale-your-dask-cluster-with-kubernetes
######################################
helm repo add dask https://helm.dask.org/
helm repo update
export RELEASE="dask"
helm install ${RELEASE} dask/dask


######################################
# port forwarding:
# shell$ ssh -i "my.pem" -NL 45725:localhost:45725 ubuntu@ec2-18-192-23-125.eu-central-1.compute.amazonaws.com
######################################
