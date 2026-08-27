# How to install Grafana ? 

 First make a new CT then start it 

 ## After that update it with : 
 ```sh
apt update && apt upgrade -y
# i wrote it without "sudo" because i already the root
```

## Then install the prerequisites : 

```sh
apt install -y curl apt-transport-https ca-certificates gnupg lsb-release
``` 

## Docker GPG key : 

```sh
mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
``` 

## Set up Docker :

```sh
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
```

## Install Docker engine and Docker compose plugin : 

```sh
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

## Verify Docker : 

```sh
docker compose version
```

## Cerate configuration dir : 

```sh
mkdir -p /opt/monitoring && cd /opt/monitoring
``` 

## Once u create 2 files , Launch the stack : 

```sh
docker compose up -d
```








