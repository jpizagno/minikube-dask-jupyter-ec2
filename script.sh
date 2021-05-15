 ######################################
 # install docker, etc...
 ######################################
 sudo apt  update
 sudo apt-get -y install     apt-transport-https     ca-certificates     curl     gnupg-agent     software-properties-common
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
 sudo apt -y update
 sudo apt -y install docker-ce
 sudo usermod -aG docker ubuntu
 # cannot switch user, cannot run docker as root
sudo adduser --disabled-password --gecos "" yelper 
 sudo usermod -aG docker yelper


 ######################################
 # install minikube
 # https://minikube.sigs.k8s.io/docs/start/
 ######################################
 curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
 sudo dpkg -i minikube_latest_amd64.deb


######################################
# install kubectl
######################################
 sudo snap install kubectl --classic


######################################
# install HELM
# https://helm.sh/docs/intro/install/
######################################
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt -y update
sudo apt-get -y install helm


#######################################################################
# start running programs as new user
#######################################################################
 sudo su - yelper
 nohup minikube start --driver=docker > minikube.log 2>&1 &
 echo "sleeping for 5 minutes, let minikube startup"
 sleep 300
# can check with command:   kubectl get po -A

######################################################################
# start the K8s dashboard
#######################################################################
 nohup minikube dashboard > dashboard.log 2>&1 &
#######################################################################
# The dashboard only runs on the local machine. 
# It must be port forwarded to your local machine.
# The file dashboard.log will have the full URL of the dashboard, and look like this:
#   http://127.0.0.1:43665/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
# you can find it with the command:
#    grep -hnr "http" dashboard.log  
# port forwarding Example:
# shell$ ssh -i "my.pem" -NL 34843:localhost:34843 ubuntu@ec2-3-123-43-75.eu-central-1.compute.amazonaws.com
#######################################################################

#######################################################################
# install DASK
# https://www.dabbleofdevops.com/blog/deploy-and-scale-your-dask-cluster-with-kubernetes
#######################################################################
helm repo add dask https://helm.dask.org/
helm repo update
export RELEASE="dask"
helm install ${RELEASE} dask/dask

#######################################################################
# run k8s port forwarding for DASK UI and JUPYTER
#######################################################################
export DASK_SCHEDULER="127.0.0.1"                                                             
export DASK_SCHEDULER_UI_IP="127.0.0.1"                                                       
export DASK_SCHEDULER_PORT=7080                                                               
export DASK_SCHEDULER_UI_PORT=7081                                                           
nohup kubectl port-forward --namespace default svc/dask-scheduler $DASK_SCHEDULER_PORT:8786 > DASK_SCHEDULER_PORT.log 2>&1 &     
nohup kubectl port-forward --namespace default svc/dask-scheduler $DASK_SCHEDULER_UI_PORT:80 > DASK_SCHEDULER_UI_PORT.log 2>&1 &  
echo " The DASK Scheduler UI port is $DASK_SCHEDULER_UI_PORT"
echo " port forward from your local maching like this:  "
echo "ssh -i '{your}.pem' -NL $DASK_SCHEDULER_UI_PORT:localhost:$DASK_SCHEDULER_UI_PORT ubuntu@{public-ec2-ip} &"                                          

export JUPYTER_NOTEBOOK_IP="127.0.0.1"                                                       
export JUPYTER_NOTEBOOK_PORT=7082                                                            
nohup kubectl port-forward --namespace default svc/dask-jupyter $JUPYTER_NOTEBOOK_PORT:80 > JUPYTER_NOTEBOOK_PORT.log 2>&1 & 

echo " The Jupyter Noteook is available on port $JUPYTER_NOTEBOOK_PORT"
echo " port forward from your local maching like this:  "
echo "ssh -i '{your}.pem' -NL $JUPYTER_NOTEBOOK_PORT:localhost:$JUPYTER_NOTEBOOK_PORT ubuntu@{public-ec2-ip} &"

echo "WAIT a few minutes for the workers Pods in minikube to start ...."