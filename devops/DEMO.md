# InfraWatch demonstration guide

Commands are grouped by the machine where they run. Replace VM_IP and EC2_PUBLIC_IP with the current addresses. Do not copy terminal prompts.

## 1. Check the application - Debian terminal

```bash
cd ~/infrawatchapp
git status --short
docker compose --env-file devops/.env -f devops/compose.yaml ps
cat devops/nginx/active.inc
curl -i http://localhost:8080/health
```

Expect one active application instance, Nginx running, and HTTP 200. Open http://VM_IP:8080 in a browser. The stopped application slot is the standby instance.

## 2. Deployment and rollback - GitHub

Open Actions > InfraWatch Deploy:

1. Select main and a published tag, such as ci-14.
2. For a normal deployment, leave test_rollback unchecked.
3. Follow the active service selection, image download, backup, and target activation.
4. Repeat the service and health checks above.

Using the same image tag demonstrates switching between slots, but does not demonstrate a functional application change.

To demonstrate rollback, run the workflow with test_rollback checked. A failed workflow is expected: the script introduces an intentional error and returns to the previous instance. Show the recovery message in the logs, then HTTP 200 and the working dashboard.

Do not run manual activation commands alongside a workflow deployment.

## 3. Prepare Terraform - Debian terminal

Requirements: Terraform, AWS CLI, the default AWS profile in ~/.aws/credentials, a local SSH key, and internet access. Do not commit AWS credentials or the private SSH key.

```bash
cd ~/infrawatchapp/devops/terraform
aws sts get-caller-identity
ls -l ~/.ssh/infrawatch-ec2.pub
```

For a new installation only, if the key does not exist:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/infrawatch-ec2
```

Do not overwrite an existing key. Terraform registers only the public .pub file with AWS; the private key stays on Debian.

Before planning, check:

- providers.tf selects eu-central-1 and the default profile.
- The default VPC exists in that region.
- The SSH rule in network.tf contains the current connection's public IP with /32. If presenting from another network, update that rule and review the plan. The VM's private LAN address is not your public IP.
- The ../../app/ paths in main.tf point to the agent source within this repository.

```bash
ls -l ../../app/agent/linux/agent.py ../../app/agent/version.json
terraform init
terraform validate
terraform plan -out=ec2-demo.tfplan
```

Read the saved plan before applying it. A fresh environment creates three managed resources: an instance, a public key registration, and a Security Group. An existing environment may produce a different plan. A stopped instance is not automatically started by a normal Terraform apply.

```bash
terraform apply ec2-demo.tfplan
terraform output -raw server_ip
```

Use the resulting IP, which may differ from an earlier demonstration. If resources already exist, use their current state and review the plan rather than assuming a fresh creation.

## 4. Open the SSH tunnel - start from Debian

The dashboard stays on Debian. EC2 cannot directly access your home VM's private address. The reverse tunnel connects EC2's local port 9000 to Nginx on Debian through SSH.

```bash
ssh -i ~/.ssh/infrawatch-ec2 -o ExitOnForwardFailure=yes -R 127.0.0.1:9000:127.0.0.1:8080 ec2-user@EC2_PUBLIC_IP
```

This also opens an EC2 shell. Leave the session open during monitoring. Port 9000 is bound to EC2 loopback rather than exposed publicly. If SSH is unavailable immediately after creation, allow the server time to start and try again.

## 5. Verify the agent - EC2 terminal

```bash
sudo cloud-init status --wait
sudo systemctl status infrawatch-agent --no-pager
sudo journalctl -u infrawatch-agent -n 20 --no-pager
```

At first boot, user data installs Python and the agent, creates its service account, and enables the systemd service. The agent contacts http://127.0.0.1:9000, the EC2 end of the SSH tunnel.

Read the temporary code from the log. In the dashboard, select Devices > Add device > Computer / Server and approve the code as an administrator before it expires.

Show the EC2 device in Overview and Device details: hostname, Linux, CPU, RAM, uptime, and free space. GPU telemetry is unavailable on the Linux agent.

The service starts at boot and retains its approved connection. Metric delivery still depends on the dashboard and tunnel. A recreated EC2 instance is a new device and needs new approval.

## 6. Optional local agent test - separate Debian terminal

Download and extract the Linux agent, then open the InfraWatch-Agent directory:

```bash
python3 agent.py --server http://127.0.0.1:8080 --state-dir ~/.config/infrawatch-local-test
```

Approve the code if that state directory has no valid saved connection. Reuse the same directory to reconnect. Ctrl+C stops the manually started agent.

Loopback works because this agent runs on the same Debian host as the dashboard. A separate LAN device must use the VM's reachable address. If a saved connection is rejected after device removal, use a new state directory and approve a new code.

## 7. After the demonstration

Run exit in the SSH session to close the tunnel. EC2 will appear offline after metrics stop arriving.

To remove resources managed by this Terraform configuration, run on Debian:

```bash
cd ~/infrawatchapp/devops/terraform
terraform plan -destroy -out=cleanup.tfplan
```

Review the proposed deletions. Only proceed if these are the resources you intend to remove:

```bash
terraform apply cleanup.tfplan
```

Termination also deletes the configured root disk. Do not delete Terraform state as a way to stop infrastructure. Stopping EC2 in the console retains its disk and can still incur storage charges; starting it again can change its public IP.

To stop the local application after the demonstration:

```bash
cd ~/infrawatchapp
docker compose --env-file devops/.env -f devops/compose.yaml --profile standby stop
```

This keeps containers and persistent data. To resume, read active.inc, start only the service it selects, wait for healthy, and start Nginx.

Keep a separate backup of Terraform state outside the repository. State files and runtime configuration are intentionally excluded from Git. When updating documentation, copy individual Markdown files; do not replace the devops directory.

## Presentation talking points

- Docker packages the application and dependencies in a reproducible image.
- GHCR stores images; ci-N identifies a selectable build.
- CI tests source changes before publishing. CD deploys a selected build on the Debian runner.
- Nginx provides a stable address regardless of the active application slot.
- The volume preserves data when a container is replaced.
- Activation includes a controlled interruption to protect JSON data from concurrent writers.
- Terraform provisions the monitored server; user data installs its agent; systemd supervises the process.
- The SSH tunnel connects EC2 to the home-hosted dashboard without publishing the dashboard on the internet.
- Installation is automated, while initial pairing requires manual approval.

Keep screenshots of successful CI, deployment, the rollback demonstration, and EC2 online as a fallback if presentation-day connectivity is unavailable.
