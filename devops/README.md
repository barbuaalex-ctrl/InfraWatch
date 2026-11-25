# InfraWatch - DevOps

## Repository structure

- `app/`: the Node.js application, frontend, and Windows/Linux agents.
- `devops/Dockerfile`: the application image; Python is included for the health check.
- `devops/compose.yaml`: the two application slots and Nginx.
- `devops/nginx/`: reverse proxy configuration.
- `devops/deploy.sh`: preflight checks, backup, activation, and rollback.
- `.github/workflows/`: CI and deployment workflows.
- `devops/terraform/`: the monitored AWS EC2 server.

The dashboard runs on the Debian VM. EC2 runs the Linux agent and sends metrics to the dashboard through an SSH tunnel.

## Services and persistent data

| Role | Compose service | Container | VM host port |
| --- | --- | --- | --- |
| Blue | infrawatch | infrawatch | 3001 |
| Green | green | infrawatch-green | 127.0.0.1:3002 |
| User entry point | nginx | infrawatch-nginx | 8080 |

The application listens on port 3000 inside its container. Nginx receives requests on host port 8080 and forwards them to the active application. Green can be tested directly on port 3002 from the VM itself.

Both application slots mount the same external volume, `infrawatch-data`, at `/app/backend/data`. The application stores data in JSON files, so **Blue and Green must not run simultaneously against this volume**.

Deployment alternates between Blue and Green with a short, controlled interruption. This implementation does not provide zero-downtime deployment. A temporary container checks the new image without production data; the old production instance then stops before the new one starts.

## First startup with Docker Compose

These steps are for a new Linux installation with Git, Docker Engine, and the Compose plugin already installed. If the application is already deployed, use the deployment workflow instead of resetting its runtime configuration.

```bash
git clone https://github.com/barbuaalex-ctrl/InfraWatch.git
cd InfraWatch
docker volume create infrawatch-data
```

Create `devops/.env` with both image tags. This example uses the published and tested `ci-14` image:

```dotenv
IMAGE_TAG=ci-14
GREEN_IMAGE_TAG=ci-14
```

The existing `devops/.env.example` contains only IMAGE_TAG; the current Compose configuration also requires GREEN_IMAGE_TAG.

Create `devops/nginx/active.inc` containing this line to start with Blue:

```nginx
proxy_pass http://infrawatch:3000;
```

Run from the repository root:

```bash
docker compose --env-file devops/.env -f devops/compose.yaml config
docker compose --env-file devops/.env -f devops/compose.yaml pull infrawatch nginx
docker compose --env-file devops/.env -f devops/compose.yaml up -d infrawatch
docker inspect infrawatch --format '{{.State.Health.Status}}'
```

Wait for `healthy`. If the result is `starting`, repeat the last command after a few seconds. If it is `unhealthy`, inspect the logs before continuing.

```bash
docker compose --env-file devops/.env -f devops/compose.yaml up -d nginx
curl -i http://localhost:8080/health
```

Expect HTTP 200 with `{"status":"ok"}`. Open `http://VM_IP:8080` in a browser.

The application services use the `standby` profile and are started explicitly by service name. Do not use `--profile standby up -d`: that would start both against the shared data.

The local files `devops/.env` and `devops/nginx/active.inc` are ignored by Git. The first stores image tags; the second selects the active service. Nginx's default.conf includes active.inc. Internal upstream addresses use HTTP.

## CI: testing and publishing

The InfraWatch CI workflow runs on pushes to main, pull requests targeting main, or a manual trigger:

1. Check out the source on a GitHub-hosted Ubuntu runner.
2. Install Node.js 24 and application dependencies with npm ci.
3. Run npm test from app/.
4. Build the Docker image.
5. On main, authenticate to GHCR with the automatic GITHUB_TOKEN and publish the image.

The `ci-N` tag uses the workflow run number. It identifies a build, separately from the application and agent version, such as `0.10.0`. Publishing an image does not automatically update the VM.

## CD: deployment through GitHub Actions

Open **Actions > InfraWatch Deploy > Run workflow**. Select main, enter an already published image tag, and leave test_rollback unchecked for a normal deployment.

The trigger is manual; activation and rollback steps are automated.

The workflow requires an online, self-hosted Linux x64 runner with the `infrawatch-deploy` label, Docker access, and permission to write to the application checkout. This project's checkout is `/home/adi/infrawatchapp`.

The deployment workflow does not check out code or run git pull. It executes the script and configuration already present in that directory. Update the VM checkout before deploying changes to those scripts. The path is hardcoded in both the workflow and deploy.sh; adapt both when using another server.

### Deployment variables

| Variable | Purpose |
| --- | --- |
| IMAGE | Registry image address without its tag. |
| RELEASE_TAG | The selected build, for example ci-14. |
| ACTIVE_SERVICE | The service currently receiving traffic, read from active.inc. |
| TARGET_SERVICE | The other service, where the selected version will run. |
| TAG_KEY | The .env setting to update: IMAGE_TAG or GREEN_IMAGE_TAG. |
| SIMULATE_FAILURE | Enables the intentional failure used to demonstrate rollback. |
| GITHUB_ENV | A file supplied by GitHub Actions; values written here become environment variables in subsequent steps of the same job. |

Each workflow step runs separately. Writing the target selection to GITHUB_ENV lets later steps and the deployment script use the same decision.

The concurrency group allows one deployment from this workflow at a time. Setting cancel-in-progress to false prevents a new request from cancelling an ongoing deployment. This does not prevent someone from running conflicting Docker commands manually.

### What deploy.sh does

1. Validate the tag format and save the runtime configuration in a backup directory.
2. Start a temporary container without a network or production volume, limited to 256 MB of memory. Check the application from inside that container.
3. Stop both application services to prevent concurrent writes.
4. Copy the active instance's data into a backup under /home/adi/infrawatch-backups/.
5. Update the target's image tag in .env, start the target, and check its health.
6. Confirm that the target mounts infrawatch-data.
7. Write the target to active.inc, validate and reload Nginx, and check the application through port 8080.

The previous instance stays stopped. There is no need to switch Blue/Green manually for each deployment.

### Rollback and limitations

If activation fails, the script stops the target, restores the saved runtime configuration, restarts the previous instance, and reloads Nginx. If it cannot confirm that the target stopped or that the old instance restarted successfully, it reports that manual intervention is needed.

The test_rollback option deliberately fails after the target starts and passes its health check, but before traffic switches. The workflow is marked as failed even if recovery succeeds: the requested deployment did not complete. Verify recovery with HTTP 200 on port 8080.

Data remains in the shared volume. Rollback does not automatically restore the data backup and assumes that the previous application version can read the current data. There is no automatic ten-minute observation period or guaranteed recovery from incompatible data format changes.

Docker health checks report application health. The unless-stopped restart policy does not restart a container solely because it becomes unhealthy.

## Terraform and the demonstration

Terraform provisions an Amazon Linux EC2 instance, an SSH public key registration, and a Security Group in the existing default VPC. User data installs the agent and enables a systemd service. Initial device enrollment still requires the SSH tunnel and approval of a temporary pairing code.

See the [demo guide](DEMO.md) for presentation commands, checks, and cleanup.
