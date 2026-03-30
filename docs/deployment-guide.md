# Deployment Guide

This guide covers how to deploy packs from this repository to Bedrock Dedicated Server instances, including test/prod separation, safe production promotion, and rollback procedures.

---

## Environment Setup

### Config Files

Copy the example environment files and fill in the values for your servers:

```bash
cp environments/test.example.env environments/test.env
cp environments/prod.example.env environments/prod.env
```

Each `.env` file contains:

```bash
# Name of the Docker container running the Bedrock server
CONTAINER_NAME=bedrock-test

# Absolute path on the Docker host where the world folder is mounted
HOST_WORLD_PATH=/opt/bedrock/worlds/TestWorld

# Name of the world inside the server
WORLD_NAME=TestWorld

# Path inside the container where behavior packs live
BEHAVIOR_PACK_DEST=/data/behavior_packs

# Path inside the container where resource packs live
RESOURCE_PACK_DEST=/data/resource_packs
```

> **Never commit `.env` files** — they are git-ignored. Only the `.example.env` templates are committed.

---

## Deployment Scripts

### validate-pack.sh

Validates a pack's structure and JSON files before deployment.

```bash
bash scripts/validate-pack.sh <pack-directory>

# Example
bash scripts/validate-pack.sh packs/days-survived
```

**What it checks:**
- `manifest.json` exists and is valid JSON
- `header.uuid` and `modules[0].uuid` are present
- All `.json` files under the pack are valid JSON
- All `.mcfunction` files are non-empty

### build-pack.sh

Packages a named pack into a `.zip` for distribution or deployment.

```bash
bash scripts/build-pack.sh <pack-name>

# Example
bash scripts/build-pack.sh days-survived
# Output: dist/days-survived.zip
```

### deploy-pack.sh

Deploys a single pack to a named environment.

```bash
bash scripts/deploy-pack.sh <pack-name> <environment>

# Examples
bash scripts/deploy-pack.sh days-survived test
bash scripts/deploy-pack.sh days-survived prod
```

**What it does:**
1. Runs `validate-pack.sh` — fails fast if validation fails
2. Copies `packs/<pack-name>/` into the server's `behavior_packs/` directory
3. Updates `world_behavior_packs.json` with the pack's UUID and version
4. Restarts the container (or sends a reload command)
5. Writes a timestamped entry to `logs/deployments.log`

### deploy-all.sh

Deploys every pack under `packs/` to the named environment.

```bash
bash scripts/deploy-all.sh <environment>

# Example
bash scripts/deploy-all.sh test
```

### sync-to-container.sh

Copies a pack directory directly into a running Docker container without a full restart. Useful for iterating quickly during development.

```bash
bash scripts/sync-to-container.sh <pack-name> <environment>

# Example
bash scripts/sync-to-container.sh days-survived test
```

### promote-to-prod.sh

Orchestrates the full test-verified promotion workflow as a single safe command. Validates the pack, checks the deployment log for a prior successful test deployment, requires explicit "yes" confirmation, and then deploys to production.

```bash
bash scripts/promote-to-prod.sh <pack-name>

# Example
bash scripts/promote-to-prod.sh days-survived
```

**What it does:**
1. Runs `validate-pack.sh` — fails fast if validation fails
2. Checks `logs/deployments.log` for a recorded test deployment
3. Warns and prompts if no test deployment is found
4. Requires typing `yes` before touching production
5. Calls `deploy-pack.sh <pack-name> prod`

### rollback-pack.sh

Restores a pack from an automatic backup created by `deploy-pack.sh` and re-deploys it to the target environment. Optionally accepts a specific backup timestamp; defaults to the most recent backup.

```bash
bash scripts/rollback-pack.sh <pack-name> <environment> [backup-timestamp]

# Examples
bash scripts/rollback-pack.sh days-survived prod              # latest backup
bash scripts/rollback-pack.sh days-survived prod 20240115_142301
```

**What it does:**
1. Locates the target backup under `logs/backups/<pack-name>-<timestamp>/`
2. Requires typing `yes` before proceeding
3. Restores the backup files to `packs/<pack-name>/`
4. Re-deploys via `deploy-pack.sh`
5. Appends a `ROLLBACK` entry to `logs/deployments.log`

---

## Test-to-Production Workflow

### Rule: never deploy directly to production without a test pass

The recommended promotion path uses `promote-to-prod.sh`, which enforces the test-first check and requires explicit confirmation:

```
1. Edit pack files
2. bash scripts/validate-pack.sh packs/<pack-name>
3. bash scripts/deploy-pack.sh <pack-name> test
4. Verify behavior in the test world
5. bash scripts/promote-to-prod.sh <pack-name>
```

Alternatively, `deploy-pack.sh` can target production directly, but will prompt for confirmation:

```bash
bash scripts/deploy-pack.sh <pack-name> prod
# Prompts: "Type 'yes' to confirm direct production deployment:"
```

### World Registration

Behavior packs must be registered to a world to take effect. The deploy scripts handle this, but the files they manage are:

- `<host-world-path>/world_behavior_packs.json`
- `<host-world-path>/world_resource_packs.json`

Format:

```json
[
  {
    "pack_id": "<header.uuid from manifest.json>",
    "version": [1, 0, 0]
  }
]
```

---

## Docker Setup

See `docker/examples/` for ready-to-use Compose files.

### Start the test server

```bash
docker compose -f docker/examples/docker-compose.test.yml up -d
```

### Start the production server

```bash
docker compose -f docker/examples/docker-compose.prod.yml up -d
```

### Start multiple servers in parallel

`docker-compose.multi.yml` runs two servers side by side (survival + creative). Copy the matching environment templates and edit them before deploying packs:

```bash
cp environments/survival.example.env environments/survival.env
cp environments/creative.example.env environments/creative.env
docker compose -f docker/examples/docker-compose.multi.yml up -d
```

Deploy packs to each server using its environment file:

```bash
bash scripts/deploy-pack.sh days-survived survival
bash scripts/deploy-pack.sh fun-pack creative
```

### Restart a container after deployment

```bash
docker restart <CONTAINER_NAME>
```

---

## Rollback Procedure

### Quick rollback with rollback-pack.sh

Use the `rollback-pack.sh` script to restore the most recent automatic backup and re-deploy in one step:

```bash
# Roll back to the previous version on prod
bash scripts/rollback-pack.sh days-survived prod

# Roll back to a specific backup
bash scripts/rollback-pack.sh days-survived prod 20240115_142301
```

The script lists available backups, prompts for confirmation, restores the pack files, re-deploys, and writes a `ROLLBACK` entry to the deployment log.

### Manual rollback (revert via git)

```bash
# Deploy the previous pack version from git
git stash   # or git checkout <previous-commit> -- packs/<pack-name>
bash scripts/promote-to-prod.sh <pack-name>
```

### Manual rollback (copy backup)

Deploy scripts automatically back up the previous pack version to `logs/backups/<pack-name>-<timestamp>/` before overwriting. To restore manually:

```bash
# Find the backup
ls logs/backups/

# Copy backup into the pack directory
cp -r logs/backups/<pack-name>-<timestamp>/<pack-name>/. packs/<pack-name>/

# Re-deploy
bash scripts/promote-to-prod.sh <pack-name>
```

### Removing a pack entirely

To detach a pack from a world:
1. Edit `<host-world-path>/world_behavior_packs.json` and remove the pack entry
2. Restart the Bedrock server container
3. Optionally remove the pack directory from `behavior_packs/`

---

## Deployment Logs

All deploy and rollback operations append a record to `logs/deployments.log`:

```
[2024-01-15 14:23:01] DEPLOY pack=days-survived env=test uuid=<uuid> backup=logs/backups/days-survived-20240115_142301 status=SUCCESS
[2024-01-15 14:30:45] DEPLOY pack=days-survived env=prod uuid=<uuid> backup=logs/backups/days-survived-20240115_143045 status=SUCCESS
[2024-01-15 15:00:12] ROLLBACK pack=days-survived env=prod from=logs/backups/days-survived-20240115_142301 status=SUCCESS
```

Logs are git-ignored. Rotate or archive them as needed.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Pack not appearing in-game | Check `world_behavior_packs.json` UUID matches `manifest.json` header UUID exactly |
| Functions not running | Verify `tick.json` exists and references the correct function path |
| Scoreboards not created | Run `/function <namespace>/init` in-game on the world |
| Container not restarting | Check `CONTAINER_NAME` in the `.env` file; verify `docker ps` shows the container |
| JSON validation fails | Run `jq . packs/<pack-name>/manifest.json` to see the parse error |
