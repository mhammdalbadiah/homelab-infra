# LocalStack

Local AWS cloud emulator running on Proxmox. I use it to practice AWS services on my own hardware without paying a cent or needing an internet connection — perfect for cert prep.

## Files

```
localstack/
├── README.md            # this file — full setup walkthrough
├── config.yaml          # container settings (deploy.sh reads from this)
└── deploy.sh            # automated deployment script (run on Proxmox host)
```

## Why

I'm studying for the AWS SAA-C03 exam and I wanted a way to actually use the services instead of just reading about them. LocalStack emulates a ton of AWS services locally — S3, Lambda, DynamoDB, SQS, IAM, CloudFormation, and more. I can spin up resources, break things, and tear them down without worrying about billing or rate limits.

It also helps me build real muscle memory with the AWS CLI, so when I sit for the exam or eventually work with real AWS, the commands are second nature.

## What It Runs

LocalStack 3.8 (Community Edition) — the free tier covers most of what I need for cert prep:

- **S3** — create buckets, upload objects, set policies
- **IAM** — create users, roles, policies
- **Lambda** — deploy and invoke functions
- **DynamoDB** — create tables, run queries
- **SQS / SNS** — message queues and notifications
- **CloudFormation** — deploy stacks from templates
- **EC2 (basic)** — limited but enough for understanding API calls
- **CloudWatch** — logs and basic metrics

> The Pro version adds more services but the free tier is solid enough for SAA-C03 prep.

## How It Runs

LocalStack runs as an **LXC container** on Proxmox. Inside the container, LocalStack itself runs as a Docker container — so it's Docker inside LXC. I went with this approach to keep it isolated from everything else on the server.

| Resource | Value |
|----------|-------|
| Type | LXC (Unprivileged) |
| Cores | 2 |
| RAM | 1 GB |
| Storage | SSD (`/mnt/essd`) |
| LocalStack Version | 3.8 |

## Setup

### 1. Create the LXC Container

Log into the Proxmox web UI at `https://<proxmox-ip>:8006` with the root account (Linux PAM realm).

I used a plain **Debian 12** template for this one (not TurnKey), since LocalStack just needs Docker and nothing else.

Download the template:

```bash
# pveam = Proxmox VE Appliance Manager
# updates the list of available templates from Proxmox's online repo
pveam update

# find the Debian 12 template
pveam available --section system | grep debian-12

# download it to local storage
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

Create the container:

```bash
# pct create = create a new LXC container
# 101 = container ID
# local:vztmpl/... = path to the template
# --hostname = name of the container
# --cores, --memory, --swap = resource limits
# --rootfs = disk storage and size
# --net0 = network config (DHCP or static)
# --unprivileged 1 = security: container can't access host resources directly
# --features nesting=1 = required for running Docker inside LXC
pct create 101 \
    local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
    --hostname localstack \
    --cores 2 \
    --memory 1024 \
    --swap 512 \
    --rootfs local-lvm:8 \
    --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp,type=veth \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1
```

> `nesting=1` is critical here — without it, Docker won't work inside the LXC container.

Start it:

```bash
pct start 101
```

### 2. Install Docker

Get into the container and install Docker. LocalStack runs as a Docker container so we need the Docker engine first.

```bash
# enter the container shell from the Proxmox host
pct enter 101

# update packages
apt update && apt upgrade -y

# install dependencies
# ca-certificates = SSL certificates for HTTPS downloads
# curl = for downloading the Docker install script
# gnupg = for verifying Docker's GPG key
apt install -y ca-certificates curl gnupg

# add Docker's official GPG key
# GPG keys let apt verify that packages actually came from Docker and weren't tampered with
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# add Docker's repo to apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# verify Docker is running
docker --version
systemctl status docker
```

### 3. Run LocalStack

Now pull and run LocalStack:

```bash
# pull the LocalStack image (community edition)
docker pull localstack/localstack:3.8

# run it
# -d = detached (runs in the background)
# --name = name of the container
# -p 4566:4566 = map port 4566 (LocalStack's main endpoint) to the host
# -p 4510-4559:4510-4559 = range of ports for individual service endpoints
# -e SERVICES= = which AWS services to start (leave empty for all free services)
# -v /var/run/docker.sock = lets LocalStack spin up Lambda containers
# --restart unless-stopped = auto-restart on reboot unless manually stopped
docker run -d \
    --name localstack \
    -p 4566:4566 \
    -p 4510-4559:4510-4559 \
    -e SERVICES=s3,iam,lambda,dynamodb,sqs,sns,cloudformation,cloudwatch \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart unless-stopped \
    localstack/localstack:3.8
```

Check if it's running:

```bash
# should show the localstack container as "Up"
docker ps

# hit the health endpoint — should return "running"
curl http://localhost:4566/_localstack/health
```

### 4. Install the AWS CLI

You need the AWS CLI to interact with LocalStack — same commands you'd use with real AWS, just pointed at a different endpoint.

```bash
# install AWS CLI v2
apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# verify
aws --version
```

### 5. Configure AWS CLI for LocalStack

Since we're not talking to real AWS, the credentials can be anything — LocalStack doesn't validate them. But the CLI still requires them to be set.

```bash
# configure dummy credentials
# these are not real — LocalStack accepts anything
aws configure
# AWS Access Key ID: test
# AWS Secret Access Key: test
# Default region name: us-east-1
# Default output format: json
```

To avoid typing `--endpoint-url` on every command, I set up an alias:

```bash
# add to ~/.bashrc so it persists
echo 'alias awslocal="aws --endpoint-url=http://localhost:4566"' >> ~/.bashrc
source ~/.bashrc
```

Now I can use `awslocal` instead of `aws --endpoint-url=http://localhost:4566`:

```bash
# these two are the same:
aws --endpoint-url=http://localhost:4566 s3 ls
awslocal s3 ls
```

### 6. Tailscale (Optional)

If you want to access LocalStack from other devices (like running AWS CLI from your main PC against the homelab):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
tailscale ip -4
```

Then from your other machine, point the AWS CLI at the Tailscale IP:

```bash
aws --endpoint-url=http://<tailscale-ip>:4566 s3 ls
```

## Testing It Out

Here's a quick test to make sure everything works — create an S3 bucket and upload a file:

```bash
# create a bucket
awslocal s3 mb s3://my-test-bucket

# create a test file
echo "hello from localstack" > test.txt

# upload it
awslocal s3 cp test.txt s3://my-test-bucket/

# list the bucket contents
awslocal s3 ls s3://my-test-bucket/

# download it back
awslocal s3 cp s3://my-test-bucket/test.txt downloaded.txt
cat downloaded.txt
```

More examples:

```bash
# create a DynamoDB table
awslocal dynamodb create-table \
    --table-name Users \
    --attribute-definitions AttributeName=UserId,AttributeType=S \
    --key-schema AttributeName=UserId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# list tables
awslocal dynamodb list-tables

# create an IAM user
awslocal iam create-user --user-name testuser

# create an SQS queue
awslocal sqs create-queue --queue-name my-queue

# deploy a CloudFormation stack from a template
awslocal cloudformation deploy \
    --template-file template.yaml \
    --stack-name my-stack
```

## Useful Commands

```bash
# check LocalStack status and which services are running
curl http://localhost:4566/_localstack/health | python3 -m json.tool

# view LocalStack logs
docker logs localstack

# follow logs in real time
docker logs -f localstack

# restart LocalStack (wipes all data — it's ephemeral by default)
docker restart localstack

# stop LocalStack
docker stop localstack

# start it again
docker start localstack

# pull a newer version
docker pull localstack/localstack:latest
docker stop localstack && docker rm localstack
# then run the docker run command again with the new image
```

> **Note:** LocalStack is ephemeral — all resources (buckets, tables, queues) are wiped on restart. This is actually fine for cert prep since you practice creating everything from scratch each time.

## Links

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [LocalStack GitHub](https://github.com/localstack/localstack)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/)
- [LocalStack Coverage (which services are supported)](https://docs.localstack.cloud/references/coverage/)


