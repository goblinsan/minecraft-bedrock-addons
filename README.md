# minecraft-bedrock-addons

A structured repository for building, testing, and deploying Minecraft Bedrock Edition add-ons (behavior packs and resource packs) with a clear development workflow, reusable templates, and safe test-to-production promotion.

---

## Project Purpose

This repository provides a self-contained, opinionated workspace for Bedrock add-on development designed for:

- **Repeatable workflows** — validate, build, deploy, verify in a consistent loop
- **Safe test/prod separation** — changes always hit a dedicated test server before production
- **GitHub Copilot-assisted iteration** — structured files and clear naming conventions make Copilot suggestions more accurate
- **Easy extension** — adding a new pack means creating a folder under `packs/` and following the existing conventions

---

## Repository Layout

```
minecraft-bedrock-addons/
├── docs/                          # Project documentation
│   ├── architecture.md            # Bedrock constraints, design decisions, scoreboard patterns
│   ├── addon-development-guide.md # Step-by-step dev workflow per pack
│   ├── deployment-guide.md        # Deployment paths, testing, and rollback procedures
│   └── roadmap.md                 # Planned packs: classes, quests, loot events, fun, economy
│
├── packs/                         # One sub-directory per add-on pack
│   └── days-survived/             # Example: days-survived behavior pack
│       ├── manifest.json
│       ├── pack_icon.png
│       └── functions/
│
├── shared/                        # Assets and templates shared across packs
│   └── templates/
│       ├── behavior-pack-manifest.json   # Manifest template with placeholder UUIDs
│       ├── resource-pack-manifest.json   # Resource pack manifest template
│       └── new-pack-template/            # Complete pack scaffold (used by new-pack.sh)
│           ├── manifest.json
│           └── functions/
│               ├── tick.json
│               └── template/
│                   ├── init.mcfunction
│                   └── tick.mcfunction
│
├── scripts/                       # Shell scripts for validate/build/deploy workflows
│   ├── new-pack.sh                # Scaffold a new pack from the template with auto-UUIDs
│   ├── validate-pack.sh           # Validate structure, manifest, and JSON
│   ├── build-pack.sh              # Package a named pack for deployment
│   ├── deploy-pack.sh             # Deploy a single pack to a target environment
│   ├── deploy-all.sh              # Deploy all packs to a target environment
│   ├── sync-to-container.sh       # Copy pack files into a running Docker container
│   ├── generate-uuid.sh           # Generate UUID v4 pairs; optionally inject into manifest
│   ├── promote-to-prod.sh         # Safe test-verified production promotion workflow
│   └── rollback-pack.sh           # Restore a pack from backup and re-deploy
│
├── environments/                  # Per-environment config files
│   ├── test.example.env           # Test server config template
│   ├── prod.example.env           # Production server config template
│   ├── survival.example.env       # Multi-server: survival world config template
│   └── creative.example.env       # Multi-server: creative world config template
│
├── docker/
│   └── examples/                  # Docker Compose examples
│       ├── docker-compose.test.yml    # Single test server
│       ├── docker-compose.prod.yml    # Single production server
│       └── docker-compose.multi.yml   # Two servers running in parallel
│
├── logs/                          # Deployment logs (git-ignored)
├── .gitignore
└── README.md
```

---

## Quick Start

### Prerequisites

- Bash (macOS/Linux or WSL on Windows)
- `jq` for JSON validation (`brew install jq` / `apt install jq`)
- Docker (for running local Bedrock servers)
- A copy of the [Bedrock Dedicated Server](https://www.minecraft.net/en-us/download/server/bedrock) or a Docker image

### 1. Clone the Repository

```bash
git clone https://github.com/goblinsan/minecraft-bedrock-addons.git
cd minecraft-bedrock-addons
```

### 2. Configure Your Environment

Copy the example environment files and fill in your server paths:

```bash
cp environments/test.example.env environments/test.env
cp environments/prod.example.env environments/prod.env
# Edit each file with your actual container names and world paths
```

### 3. Create a New Pack

```bash
# Use new-pack.sh to scaffold a pack from the template (auto-generates UUIDs)
bash scripts/new-pack.sh my-new-pack
# Edit packs/my-new-pack/manifest.json — update name and description
# Add your functions/ folder and mcfunction files
```

See [docs/addon-development-guide.md](docs/addon-development-guide.md) for the full walkthrough.

### 4. Validate Your Pack

```bash
bash scripts/validate-pack.sh packs/my-new-pack
```

### 5. Deploy to the Test Server

```bash
bash scripts/deploy-pack.sh my-new-pack test
```

### 6. Promote to Production

After verifying behavior on the test server:

```bash
bash scripts/promote-to-prod.sh my-new-pack
```

---

## Development Flow

```
Edit code  →  validate-pack.sh  →  deploy-pack.sh (test)
                                        ↓
                               Verify on test server
                                        ↓
                          promote-to-prod.sh  →  Done
```

Full details: [docs/addon-development-guide.md](docs/addon-development-guide.md)

---

## Deployment Overview

Scripts read configuration from `environments/<env>.env` and copy pack files to the correct Bedrock server paths. Docker containers are restarted automatically when needed.

| Script | Purpose |
|---|---|
| `new-pack.sh` | Scaffold a new pack from the template with auto-generated UUIDs |
| `validate-pack.sh` | Check structure, manifest fields, and JSON syntax |
| `build-pack.sh` | Zip a pack for deployment or sharing |
| `deploy-pack.sh` | Deploy one pack to a named environment (with prod confirmation guard) |
| `deploy-all.sh` | Deploy every pack under `packs/` |
| `sync-to-container.sh` | Copy files into a live Docker container |
| `generate-uuid.sh` | Generate two UUID v4 values; optionally inject them into a manifest with `--inject` |
| `promote-to-prod.sh` | Full test-verified promotion workflow: validate → test-check → confirm → prod |
| `rollback-pack.sh` | Restore a pack from an automatic backup and re-deploy |

Full details: [docs/deployment-guide.md](docs/deployment-guide.md)

---

## Documentation

| Document | Description |
|---|---|
| [architecture.md](docs/architecture.md) | Bedrock constraints, pack structure, manifest guidance, scoreboard patterns |
| [addon-development-guide.md](docs/addon-development-guide.md) | How to create, validate, and iterate on a pack |
| [deployment-guide.md](docs/deployment-guide.md) | Deployment workflow, test/prod promotion, rollback |
| [roadmap.md](docs/roadmap.md) | Planned packs with recommended patterns: classes, daily quests, loot events, fun pack, economy |

---

## Contributing

1. Create your pack directory under `packs/`
2. Follow the manifest and function naming conventions in [docs/architecture.md](docs/architecture.md)
3. Run `validate-pack.sh` before opening a PR
4. Document any new pack behavior in its own `packs/<pack-name>/README.md`