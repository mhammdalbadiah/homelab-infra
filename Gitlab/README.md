# check out the installtion guide on 

https://docs.gitlab.com/install/package/debian/?tab=Community%20Edition


## install curl 

```sh 
apt update && apt install -y curl
```

## install sudo 

```sh
apt update && apt install -y sudo
```

## Create a new user 

```sh
adduser --allow-bad-names <username>
```
## Add the new user to sudo group 

```sh
usermod -aG sudo <username>
groups <username>
```

## exit the root user and login with your new user 


## install Gitlab for Debian 

```sh 
curl --location "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh" | sudo bash
```
