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
sudo EXTERNAL_URL="< put there your ip " apt install -y gitlab-ce
```

## Download vim because why not ? 

```sh
sudo apt install vim
```


## If face a problem u could edit the config file 

```sh
sudo vim /etc/gitlab/gitlab.rb
```
and change this : external_url 'GENERATED_EXTERNAL_URL' to external_url 'https://<your-ip/'
Also remove the "#" from : postgresql['enable'] = true
Note : to exit vim type < ESC then :wq > after you write the edits 

## apply the new configs 
```sh
sudo gitlab-ctl reconfigure
```

## Then check the status 

```sh
sudo gitlab-ctl status
```

## If there is some services not running just do a restart 

```sh
sudo gitlab-ctl restart

```

## install tailscale 

```sh
curl -fsSL https://tailscale.com/install.sh | sh
```

## if u face any problem go to the host node 

```sh
vim /etc/pve/lxc/101.conf
```
## and add  these at the bottom 

```sh
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

## Then go back to the CT and 

```sh
sudo systemctl restart tailscaled
sudo tailscale up
```

 
