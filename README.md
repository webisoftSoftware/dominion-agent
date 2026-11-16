# Dominion Agent

Run your own poker agent connected to Dominion. The companion manages local wallets
and sends poker decisions to your chosen strategy: Starter, AI through OpenRouter,
or a custom endpoint. Wallet recovery material and strategy secrets stay local.
Each build plays one network: the `v*` releases play Midnight Stagenet at
https://dominion-stagenet.1am.xyz/, the `mainnet-v*` releases play Mainnet at https://dominion.1am.xyz/.
Use the install command shown in My Agents on each site, and a separate directory per network.
The former hosted preprod game has been retired.

## Release status

`v0.2.4` is the current installer. It uses the `v0.2.2` image, the Ledger 9 release for Linux AMD64 and ARM64.
Agents can play cash tables and tournaments in any unshielded token the play rules
name (for example GOLD or CHIP), not only NIGHT. Both architectures passed checks
for wallet creation, native card and engine modules, Stagenet verifier keys
and version reporting. Funded gameplay was outside this release check.

The public image is hosted on [Docker Hub](https://hub.docker.com/r/adglx/dominion-agent)
as `adglx/dominion-agent`. Users do not need a Docker Hub account or registry login.
The GHCR copy remains private under organization policy. Verified image archives are also
attached to the release.
Do not use the preprod-only `v0.1.0` image with the new site.

## Install

For Mainnet (real NIGHT), use the [`mainnet-v0.3.0`](https://github.com/webisoftSoftware/dominion-agent/releases/tag/mainnet-v0.3.0)
release (image `docker.io/adglx/dominion-agent:0.3.0-mainnet`, files in `mainnet/`):

```sh
curl -fsSL https://github.com/webisoftSoftware/dominion-agent/releases/download/mainnet-v0.3.0/install.sh | sh
```

If `~/dominion-bot` already holds a Stagenet install, the installer refuses it; prefix `sh` with
`DOMINION_BOT_HOME="$HOME/dominion-bot-mainnet"` instead.

For Stagenet:

```sh
curl -fsSL https://github.com/webisoftSoftware/dominion-agent/releases/download/v0.2.4/install.sh | sh
```

The installer creates `~/dominion-bot`, downloads Compose pinned to the release image digest,
and starts setup. Pair the code shown in the terminal with My Agents on Dominion, then complete
wallet creation/import and backup locally. Wallet secrets never need to be entered on the website.

Release `v0.2.2` includes the 1AM CLI `0.1.7`, built from wallet source
`6b98584aa339e8f719a9fba7b03106cb094a1c62` with the patched ledger 8 and 9 WASMs.
Companion runtime source: `3a2f662e6c285a6a0996e6ed02faa71c626b1ec4`, prepared with its
Ledger 9 profile. Release assets include `BUILD-MANIFEST.json`, `VERIFICATION.json` and `SHA256SUMS`.
Images support Linux AMD64 and ARM64, including Docker Desktop on macOS.

This repository contains the installer and Compose deployment files. Companion source and builds
are maintained in the Dominion Midnight repository under `bot-companion/`.

## Requirements

- macOS or Linux with Docker running and Docker Compose v2 installed.
- Access to Dominion's My Agents page and its configured bot host.
- A wallet funded with Stagenet NIGHT and usable DUST before playing.

The public repository and image names are `webisoftSoftware/dominion-agent` and
`docker.io/adglx/dominion-agent`. The existing command is `dominion-bot`,
configuration uses `DOMINION_BOT_*`, and installation defaults to `~/dominion-bot`.

## Local installation

Build the Ledger 9 `dominion-bot:stagenet` image from the companion source first, following its README.
Then, from this checkout, run:

```sh
DOMINION_BOT_HOME="$HOME/dominion-agent-test" \
DOMINION_BOT_IMAGE=dominion-bot:stagenet \
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

Rerun the installer to reopen setup. Running a newer release's install command updates the
installation in place: it installs that release's `compose.yml` (keeping `compose.yml.previous`)
and image, and keeps `.env`, `data/` and `bot/`. Let active games finish first. For an isolated test installation, pass the
same `DOMINION_BOT_HOME` each time. `sh install.sh --stop` stops services while
preserving files. `sh install.sh --delete` first unregisters the agents, then removes
containers and archives local files; it refuses deletion if unregistering fails.
Use Stop in My Agents and let active games finish before stopping containers.

Wallets and synced state live under `data/`; configuration and the wallet password
live in the private `.env`. Owner strategy files live in `bot/`. Back up recovery
phrases separately. Never commit installation data or secrets to this repository.

## Moving from preprod

Use a separate installation directory for Stagenet, for example
`DOMINION_BOT_HOME="$HOME/dominion-bot-stagenet"` when running the new installer.
Pair it again through My Agents on https://dominion-stagenet.1am.xyz/ and fund its wallet
with Stagenet NIGHT and DUST. Preprod balances, pairing tokens and game journals do not
transfer. Keep the old directory and recovery phrase as a backup; do not copy its `data/`
into the new installation. Installer reruns preserve saved origins, and the installer refuses
to move an installation saved for one Dominion network to another.

The companion selects `https://api-stagenet.1am.xyz` for proving. Configure
`POKER_PROOF_SERVER_API_KEY` in the installation's private `.env` when required by that service.

## Release maintenance

Refresh `install.sh` and `compose.yml` from the source repository's `bot-companion/`
directory, using the generated `.stagenet/bot-companion/` files for a Ledger 9 release.
Change the installer's release URL to this repository and the Compose
image to `docker.io/adglx/dominion-agent`. Keep runtime command and
configuration names unchanged.

Before publishing, build and test AMD64 and ARM64 images, then verify anonymous pulls
from Docker Hub with an empty Docker credential configuration. Publish `install.sh` and `compose.yml` as
assets of the same versioned release, with Compose pinned to that image's digest.
Verify a clean install, pairing, wallet setup and restart before advertising it.
Rerunning a release's installer updates an existing installation to that release's Compose
file and image (the previous Compose file is kept as `compose.yml.previous`). Advertise the new
install command only after the release is verified.

See `docs/agent-distribution.md` in the source repository for the complete release process.
Release notes record the CLI build and image digest for each release.

The publishing workflow maintains the private GHCR mirror and uses `contents: read` and `packages: write`. Upload both verified image
archives (`dominion-agent-amd64.tar.gz`, `dominion-agent-arm64.tar.gz`) and `SHA256SUMS` to a
published prerelease, then dispatch `publish.yml` with its tag. Draft assets are hidden from the
read-only token. Attach the installer and digest-pinned Compose file to the same release. State its registry
access requirements clearly; public image availability must be verified separately.

The Docker Hub mirror uses the same verified image contents. With a Docker Hub publisher login,
retag the two architecture images as `adglx/dominion-agent:VERSION-ARCH`, push them, then create
`VERSION` and `latest` with `docker buildx imagetools create`. Verify both platform digests and
anonymous pulls before changing the Compose pin. No Docker Hub publishing credentials are
configured in the GitHub workflow.
