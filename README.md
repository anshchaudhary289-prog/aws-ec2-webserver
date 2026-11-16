# AWS EC2 Web Server Deployment

Launching a Linux web server on **AWS EC2** — first done by hand in an AWS Academy lab (EC2 + Amazon Linux + Apache), now captured in this repo as a repeatable setup: one script that installs and configures the server, one status page it serves, and the full manual steps so the process is understood, not just automated.

## Architecture

```text
                 +------------------- EC2 instance (t2.micro) -------------------+
Browser ----HTTP (port 80)---->  Security Group  ->  nginx  ->  /var/www/html/index.html
Admin   ----SSH  (port 22)---->  Security Group  ->  sshd   ->  shell (key pair login)
                 +----------------------------------------------------------------+
```

- **Instance:** EC2 `t2.micro` (free-tier eligible), Linux (Amazon Linux / Ubuntu — the setup script detects the package manager)
- **Web server:** nginx, installed and enabled by `scripts/setup-webserver.sh`
- **Page served:** `index.html` from this repo (a simple deployment status page)

> Honest note: the original hands-on lab used **Apache** on Amazon Linux, configured manually over SSH. The script in this repo automates the same outcome with **nginx** (lighter on a `t2.micro`). The manual Apache steps are kept below because that is what was actually done first.

## What was done in the original lab

- Launched an EC2 `t2.micro` Linux instance on AWS Academy
- Connected via SSH with a key pair
- Installed the Apache web server by hand
- Configured Security Groups for HTTP (port 80) and SSH (port 22)
- Deployed a basic web page and opened it from the public IP

## Security group rules

| Direction | Port | Protocol | Source | Why |
|---|---|---|---|---|
| Inbound | 22 | TCP | Your IP only (`<your-ip>/32`) | SSH administration — never open this to `0.0.0.0/0` |
| Inbound | 80 | TCP | `0.0.0.0/0` | Public HTTP for the website |
| Outbound | All | All | `0.0.0.0/0` | Package installs and updates (default) |

## Option A — automated setup (this repo's script)

1. Launch the instance (EC2 console): Linux AMI, `t2.micro`, create/select a key pair, security group as in the table above.
2. SSH in:

   ```bash
   ssh -i your-key.pem ec2-user@<public-ip>     # Amazon Linux
   # or: ssh -i your-key.pem ubuntu@<public-ip> # Ubuntu
   ```

3. Copy this repo onto the instance (e.g. `git clone` it), then run:

   ```bash
   chmod +x scripts/setup-webserver.sh
   ./scripts/setup-webserver.sh
   ```

   The script detects `apt` (Ubuntu/Debian) or `yum`/`dnf` (Amazon Linux), installs nginx, enables it to start on boot, starts it, deploys this repo's `index.html` as the served page, and prints the instance's public IP (read from the EC2 metadata endpoint, with a fallback message if metadata is unreachable).

## Option B — user data (zero manual steps)

Paste [`user-data.sh`](user-data.sh) from this repo into **Advanced details → User data** while launching the instance. It runs the same install steps automatically on first boot, so the web server is live as soon as the instance finishes starting — no SSH needed for setup.

## Option C — the original manual steps (Apache, as done in the lab)

```bash
ssh -i your-key.pem ec2-user@<public-ip>
sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable --now httpd
echo "<h1>Hello from EC2</h1>" | sudo tee /var/www/html/index.html
```

## Verification

From your own machine:

```bash
curl http://<public-ip>
# -> returns the "Deployed on AWS EC2" page HTML

curl -I http://<public-ip>
# -> HTTP/1.1 200 OK, Server: nginx/... (or Apache, for Option C)
```

Or simply open `http://<public-ip>` in a browser — you should see the status page with the server details.

## Cleanup — avoid charges

A stopped lab is a forgotten bill. When you are done:

1. EC2 console → select the instance → **Instance state → Terminate instance** (stopping is not enough if you are finished — a stopped instance still bills for its EBS volume).
2. Check **Elastic IPs**: release any address you allocated but did not attach.
3. Check the region you used — resources in another region keep billing quietly.
4. In an AWS Academy lab the environment is torn down for you, but on a personal account this checklist is on you.

## Project structure

```text
aws-ec2-webserver/
├── README.md                  <- this file
├── index.html                 <- status page served by the web server
├── user-data.sh               <- paste into EC2 user data at launch
├── scripts/
│   └── setup-webserver.sh     <- run on an existing instance over SSH
└── .gitignore
```

## Tech stack

AWS EC2 · Linux (Amazon Linux / Ubuntu) · nginx (script) / Apache (original lab) · Security Groups · SSH · Bash · EC2 instance metadata (IMDS)

## What I learned

- An EC2 instance is just a rented Linux machine — everything after launch is ordinary Linux administration.
- Security Groups are the firewall: the server "not loading" is a port-80 rule problem more often than a server problem.
- SSH should be locked to your own IP; port 22 open to the world gets scanned within minutes.
- User data turns a 15-minute manual setup into a launch-time checkbox — the first step from clicking in consoles to infrastructure thinking.
- Always terminate and clean up: cloud billing does not care that you forgot.

## Author

**Ansh Chaudhary** — Final Year B.Tech CSE, MIET Meerut · Cloud & DevOps
LinkedIn: https://www.linkedin.com/in/ansh-chaudhary-cse
GitHub: https://github.com/anshchaudhary289-prog
