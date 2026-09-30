# Firecrawl on GitHub Codespaces

Run a self-hosted Firecrawl instance on GitHub Codespaces — free, no API keys, no local hardware required.

This repo gives you a one-command setup for Firecrawl inside a GitHub Codespace (16 GB RAM, 4-core), then tunnels it to your local machine so Claude Code (or anything else) can use it at `http://localhost:3663`.

## What you get

- Firecrawl API running on a free cloud machine (16 GB RAM / 4 cores)
- Zero API keys — no OpenAI, no Supabase, no credit card
- Auto-starts Firecrawl every time the Codespace resumes
- ~5 minutes from zero to working Firecrawl instance

## What you don't get

- **Always-on hosting.** Codespaces auto-stop after inactivity (30 min default, configurable to 4 hours). See [Keeping it alive](#keeping-it-alive) below.
- **Anti-bot bypass (Fire-engine).** Self-hosted Firecrawl doesn't include IP rotation or Cloudflare bypass. For scraping docs, GitHub repos, and public content — the 95% use case — this doesn't matter.

## Prerequisites

1. A **GitHub account** (free tier works)
2. The **GitHub CLI** (`gh`) installed on your local machine — [install guide](https://cli.github.com/)

That's it. No Docker, no Node, no Homebrew. Everything else runs inside the Codespace.

## Quick start

### 1. Create the Codespace

**From GitHub.com:**

1. Fork or use this repo
2. Click the green **<> Code** button → **Codespaces** tab → **Create codespace on main**
3. Select the **4-core (16 GB RAM)** machine type

**From the CLI:**

```bash
gh codespace create \
  --repo <your-username>/<your-repo> \
  --machine standardLinux32gb \
  --idle-timeout 240m
```

> **Core-hour math:** Free hours are measured in core-hours, not wall-clock hours. A 4-core machine uses free hours 4x faster. The 120 core-hours/month free tier = **30 actual hours** on a 4-core machine.

### 2. Wait for setup

The Codespace runs `setup.sh` automatically on creation. It:

1. Clones Firecrawl
2. Creates a minimal `.env` (port 3663, no auth, no API keys)
3. Copies a `docker-compose.override.yaml` that uses pre-built images (faster startup)
4. Starts the Docker stack
5. Waits for the health check to pass

First run takes ~2-5 minutes (image pull). Subsequent starts take ~30 seconds.

### 3. Connect from your local machine

On your **local machine** (not inside the Codespace):

```bash
# Find your Codespace name
gh codespace list

# Forward the port
gh codespace ports forward 3663:3663 -c <codespace-name>
```

Firecrawl is now at `http://localhost:3663` on your machine.

### 4. Use with Claude Code

Add this to your project's `CLAUDE.md`:

```markdown
## Firecrawl
- Base URL: http://localhost:3663
- Use `firecrawl search "query" --limit 5` for web search
- Use `firecrawl scrape "https://url"` for page extraction
```

Verify it works:

```bash
curl http://localhost:3663/v0/health/liveness
# {"status":"ok"}
```

## Keeping it alive

Codespaces stop after inactivity (no terminal input/output). Running `docker compose up -d` (detached) produces no output, so the Codespace thinks nobody's home.

**Fix 1: The tunnel keeps it alive (recommended)**

The `gh codespace ports forward` command you're already running counts as active interaction. As long as the tunnel is open on your local machine, the Codespace stays alive.

**Fix 2: Stream logs**

Inside the Codespace, stream Firecrawl logs so each request resets the idle timer:

```bash
cd /workspaces/firecrawl && docker compose logs -f
```

**Fix 3: Extend the timeout**

In GitHub Settings → Codespaces → Default idle timeout, set it to **240 minutes** (the maximum).

**Fix 4: Auto-restart on resume**

Already handled. The `postStartCommand` in `devcontainer.json` runs `setup.sh` on every start/resume, so Firecrawl comes back automatically. Just re-run the tunnel command on your local machine.

## Free tier breakdown

GitHub Free accounts get **120 core-hours/month**.

| Machine | RAM | Free wall-clock hours |
|---------|-----|-----------------------|
| 2-core | 8 GB | 60 hrs (not enough RAM for Firecrawl) |
| **4-core** | **16 GB** | **30 hrs** |
| 8-core | 32 GB | 15 hrs |

**30 hours covers:** ~4 full work days of active sessions, a serious project sprint, or hundreds of doc page scrapes.

**Storage cost:** Codespace storage is billed at $0.07/GB/month even when stopped. Expect ~5-10 GB with the Firecrawl stack, so ~$0.35-$0.70/month. Set a spending cap in GitHub Settings → Billing → Budgets.

> GitHub Pro ($4/month) gives 180 core-hours = **45 hours** on a 4-core machine.

## Connection methods

The tunnel (`gh codespace ports forward`) is recommended for Claude Code. Two other options exist:

### Public port (quick demos)

```bash
# Inside the Codespace:
gh codespace ports visibility 3663:public -c $CODESPACE_NAME
```

Gets you a public URL like `https://<name>-3663.app.github.dev`. Resets to private on every restart.

### Private port with token

```bash
# Inside Codespace:
echo $GITHUB_TOKEN  # ghu_...

# From local machine:
curl https://<name>-3663.app.github.dev \
  -H "X-Github-Token: ghu_YOUR_TOKEN"
```

Token rotates on every restart — high maintenance.

## Alternatives

| Option | Setup | Cost | Always-on | Anti-bot |
|--------|-------|------|-----------|----------|
| **Local machine** | ~10 min | Free | Yes | No |
| **Codespaces (this repo)** | ~5 min | Free (30 hrs/mo) | No | No |
| **Railway** | ~2 min | $5+/mo | Yes | No |
| **Firecrawl Cloud** | 0 min | $16+/mo | Yes | Yes |

- **Local**: Best if your machine can handle it (12+ GB RAM free).
- **Codespaces**: Best for tutorials, learning, and on-demand sessions.
- **Railway**: [Official Firecrawl template](https://railway.com). One click + $5/month.
- **Firecrawl Cloud**: Pay-as-you-go with anti-bot bypass. Right choice for scraping bot-protected sites.

## Repo structure

```
.devcontainer/
  devcontainer.json        # Codespace config: Ubuntu, docker-in-docker, auto-start
docker-compose.override.yaml  # Pre-built images (copied to /workspaces/firecrawl/ by setup.sh)
setup.sh                   # All-in-one: clone, configure, start Firecrawl
README.md                  # You are here
```

## Troubleshooting

**"Firecrawl didn't respond within 2 minutes"**

Check the logs: `cd /workspaces/firecrawl && docker compose logs`. The most common cause is images still downloading on first run.

**"WARN — You're bypassing authentication"**

Expected. `USE_DB_AUTHENTICATION=false` is the correct setting for self-hosted. Safe to ignore.

**Docker Compose errors about `!reset`**

The `docker-compose.override.yaml` uses `!reset null` (Docker Compose v2.24+). If your Codespace has an older version, delete the override and let it build from source: `rm /workspaces/firecrawl/docker-compose.override.yaml && cd /workspaces/firecrawl && docker compose up -d`

**Port 3663 not accessible after tunnel**

Make sure the tunnel is running (`gh codespace ports forward 3663:3663 -c <name>`) and that nothing else on your local machine is using port 3663.

## License

MIT
