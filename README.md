# Minikube running DASK on EC2

This will run DASK in minikube on a AWS-EC2 instance (ubuntu20, t3a.xlarge). The terraform script (main.tf) will install docker, minkube, helm, DASK, and then start DASK (web UI and Jupyter).  It creates a user called "yelper" that runs minkube, because one does not want to run dockerized apps as root. 

Here is a [link](https://www.dabbleofdevops.com/blog/deploy-and-scale-your-dask-cluster-with-kubernetes) for running DASK via Helm.


## Build/Run
The build time takes at least 15 minutes, because Terraform waits 15 minutes for Pods to start. The first 5 minutes, Terraform waits for minkube to start, and then the nexrt 10 minutes is waiting for DASK Pods to start. DASK has to wait for minikube to be up and running, and the port forwarding has to wait for the DASK Pods to be running.

Run Terraform using the python script; and provide the AWSAccessKeyId, AWSSecretKey, user's IP address (so you can ssh in later), the name of your pem file (wihtout .pem extension), and the local location of that pem file.

So if your AWSAccessKeyId='AKIAI.....FJQA' , AWSSecretKey='7VzZaTGV7......CMyrbnA', your IP=87.161.221.155, and your pem file is called my-secret.pem, and is located at /home/you/AWS/my-secret.pem, then run like this:
```
shell-local%  python3 deploy.py AKIAI.....FJQA \
    7VzZaTGV7......CMyrbnA \ 
    87.161.221.155 \
    my-secret \
    /home/you/AWS/
```
Then it takes at least 15 minutes to complete.



## Access Apps

Currently, there is no load balancer (ELB), so port forwarding is required to access the DASK UI, Jupyter notebook, and K8s dashboard.

### Jupyter
Jupyter is running on port 7082, and needs to be port forwarded to your machine.  

This is done on my local Ubuntu-20 machine like this:
```
shell-local%  ssh -i "my-secret.pem" -NL 7082:localhost:7082 ubuntu@{ec2-public-ip} &
```
where ec2-public-ip is the public ip address of the EC2 instance. 

To acess Jupyter, open your browser to http://localhost:7082.

### DASK Web UI
DASK Web UI is running on port 7081, and needs to be port forwarded to your machine.  

This is done on my local Ubuntu-20 machine like this:
```
shell-local%  ssh -i "my-secret.pem" -NL 7081:localhost:7081 ubuntu@{ec2-public-ip} &
```
where ec2-public-ip is the public ip address of the EC2 instance. 

To acess Jupyter, open your browser to http://localhost:7081.


### K8s Dashboard
The K8s Dashboard is more complicated to access. The port is randomly assinged upon startup, so you'll have to login to the EC2 instance to get the port number.

Example of how to login to the EC2 to get the port:
```
shell-local%  ssh -i "my-secret.pem"  ubuntu@{ec2-public-ip} 
ubuntu@ip-10-0-0-12:~$ grep -hnr "http" /tmp/dashboard.log  
    7:* Opening http://127.0.0.1:44817/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/ in your default browser...
    8:  http://127.0.0.1:44817/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/

```

Then port forward the above port on your local machine, in this case 44817:
```
shell-local%  ssh -i "my-secret.pem" -NL 44817:localhost:44817 ubuntu@{ec2-public-ip} &
```

Then open your browser to 
http://127.0.0.1:{enter-port-here}/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/

## Debugging
If you would like to debug minikube, login and swith to the user yelper.

Here is an example:

```
shell-local%  ssh -i "my-secret.pem"  ubuntu@{ec2-public-ip} 
ubuntu@ip-10-0-0-12:~$ sudo su - yelper
yelper@ip-10-0-0-12:~$ kubectl get all
    NAME                                  READY   STATUS    RESTARTS   AGE
    pod/dask-jupyter-7dd5dbc9dc-jf4hh     1/1     Running   0          11m
    pod/dask-scheduler-6b85c9b87f-2xczg   1/1     Running   0          11m
    pod/dask-worker-79584cb687-c4vgd      1/1     Running   0          11m
    pod/dask-worker-79584cb687-kjmk9      1/1     Running   0          11m
    pod/dask-worker-79584cb687-kmvhf      1/1     Running   0          11m

    NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE
    service/dask-jupyter     ClusterIP   10.98.166.150    <none>        80/TCP            11m
    service/dask-scheduler   ClusterIP   10.106.213.180   <none>        8786/TCP,80/TCP   11m
    service/kubernetes       ClusterIP   10.96.0.1        <none>        443/TCP           16m

    NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/dask-jupyter     1/1     1            1           11m
    deployment.apps/dask-scheduler   1/1     1            1           11m
    deployment.apps/dask-worker      3/3     3            3           11m

    NAME                                        DESIRED   CURRENT   READY   AGE
    replicaset.apps/dask-jupyter-7dd5dbc9dc     1         1         1       11m
    replicaset.apps/dask-scheduler-6b85c9b87f   1         1         1       11m
    replicaset.apps/dask-worker-79584cb687      3         3         3       11m
yelper@ip-10-0-0-12:~$ 
yelper@ip-10-0-0-12:~$ minikube status
    minikube
    type: Control Plane
    host: Running
    kubelet: Running
    apiserver: Running
    kubeconfig: Configured
```

## TODO
1. Setup ELB so user does not have to port forward
2. Add persistence volume claims
3. Setup triggers for the Pods to be available so one does not have to wait so long