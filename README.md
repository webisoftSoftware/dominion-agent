# Dominion Agent

Run your own poker agent connected to Dominion. The companion manages local wallets
and sends poker decisions to your chosen strategy: Starter, AI through OpenRouter,
or a custom endpoint. Wallet recovery material and strategy secrets stay local.
The companion currently supports Midnight preprod only.

## Release status

`v0.1.0` is staged as a prerelease. Both Linux architectures are built and verified, but the
organization currently disables public visibility for the GHCR package. An organization owner
must enable public visibility before anonymous installation works. Until then, installation requires an account with access to the package and
`docker login ghcr.io` before running the installer.

## Install

```sh
curl -fsSL https://github.com/webisoftSoftware/dominion-agent/releases/download/v0.1.0/install.sh | sh
```

The installer creates `~/dominion-bot`, downloads Compose pinned to the release image digest,
and starts setup. Pair the code shown in the terminal with My Agents on Dominion, then complete
wallet creation/import and backup locally. Wallet secrets never need to be entered on the website.

Release `v0.1.0` includes the 1AM CLI `0.1.4`, built from wallet source
`39e64c11748bbd892452656d15ba2e0dc816f6e2` with the patched ledger 8 and 9 WASMs.
Images support Linux AMD64 and ARM64, including Docker Desktop on macOS.

This repository contains the installer and Compose deployment files. Companion source and builds
are maintained in the Dominion Midnight repository under `bot-companion/`.

## Requirements

- macOS or Linux with Docker running and Docker Compose v2 installed.
- Access to Dominion's My Agents page and its configured bot host.
- A wallet funded with preprod NIGHT and usable DUST before playing.

The public repository and image names are `webisoftSoftware/dominion-agent` and
`ghcr.io/webisoftsoftware/dominion-agent`. The existing command is `dominion-bot`,
configuration uses `DOMINION_BOT_*`, and installation defaults to `~/dominion-bot`.

## Local installation

Build `dominion-bot:local` from the companion source first, following its README.
Then, from this checkout, run:

```sh
DOMINION_BOT_HOME="$HOME/dominion-agent-test" \
DOMINION_BOT_HOST=http://host.docker.internal:8792 \
DOMINION_SITE_URL=http://host.docker.internal:3003 \
sh install.sh --local
```

Adjust the URLs for your services. These example URLs reach a Mac's local services
from Docker Desktop. The isolated test directory avoids modifying an existing
installation. No companion image is pulled with `--local`; the Python strategy
service may still pull its base image.

Enter the terminal's pairing code in My Agents. Complete wallet creation or import
and backup in the terminal, then choose strategy, fund the wallet and Start on the
website. Keep pairing codes and recovery words private.

## Manage your installation

From the installation directory:

```sh
docker compose exec companion dominion-bot status
docker compose exec companion dominion-bot link
docker compose logs -f companion
```

Rerun the installer to reopen setup. For an isolated test installation, pass the
same `DOMINION_BOT_HOME` each time. `sh install.sh --stop` stops services while
preserving files. `sh install.sh --delete` first unregisters the agents, then removes
containers and archives local files; it refuses deletion if unregistering fails.
Use Stop in My Agents and let active games finish before stopping containers.

Wallets and synced state live under `data/`; configuration and the wallet password
live in the private `.env`. Owner strategy files live in `bot/`. Back up recovery
phrases separately. Never commit installation data or secrets to this repository.

## Release maintenance

Refresh `install.sh` and `compose.yml` from the source repository's `bot-companion/`
directory. Change the installer's release URL to this repository and the Compose
image to `ghcr.io/webisoftsoftware/dominion-agent`. Keep runtime command and
configuration names unchanged.

Before publishing, build and test AMD64 and ARM64 images, make the GHCR package
public, and verify an anonymous pull. Publish `install.sh` and `compose.yml` as
assets of the same versioned release, with Compose pinned to that image's digest.
Verify a clean install, pairing, wallet setup and restart before advertising it.
Existing installations keep their Compose file; rerunning the installer does not
automatically advance a pinned image. Upgrade deliberately after games finish.

See `docs/agent-distribution.md` in the source repository for the complete release process.
Release notes record the CLI build and image digest for each release.

The publishing workflow uses `contents: read` and `packages: write`. Upload both verified image
archives (`dominion-agent-amd64.tar.gz`, `dominion-agent-arm64.tar.gz`) and `SHA256SUMS` to a
published prerelease, then dispatch `publish.yml` with its tag. Draft assets are hidden from the
read-only token. After the images are public and anonymous pulls work, attach the installer and
digest-pinned Compose file and promote the release to latest.
