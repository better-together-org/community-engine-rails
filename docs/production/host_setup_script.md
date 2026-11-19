# Host Setup Script: Design and Specification

Status: specification for the rewrite of `bin/prod/host-setup.sh` (Track H of the
nlmushrooms.ca migration). The script itself changes in the follow-up pull requests
H3 (optional Elasticsearch), H2 (version manifest), H4 (standards), H5 (safety and
tests) and H6 (placement and docs). This document is the contract those changes are
reviewed against.

## Purpose and audience

`bin/prod/host-setup.sh` prepares a Linux server to run Community Engine host apps
under Dokku. It must be usable by any Community Engine adopter, so the generic
baseline lives in the gem. Better Together Solutions (BTS) fleet specifics are an
optional layer that the gem script calls through a hook; that layer is kept in the BTS
management repository, never copied into the gem.

## Current state (assessment of the script before the rewrite)

- Fourteen steps, shaped as a Raspberry Pi wizard (static IP, Wi-Fi, Bluetooth, audio).
- Three steps are placeholders that do nothing (`security_hardening` sub-steps,
  `backup_config`, `configure_storage`).
- Dokku is pinned to `v0.34.3`; plugins install unpinned from default branches;
  Docker installs from the Debian repository only; Postgres uses `postgis/postgis`
  `latest`; Redis has no version.
- Elasticsearch installs unconditionally with the other plugins.
- NordVPN and Cloudflared install by default; NordVPN via `curl | sh`.
- `apt upgrade -y` runs unconditionally; the interrupt trap exits 0.
- A single "recreate" prompt runs `apps:destroy --force`, `postgres:destroy --force`
  and `redis:destroy --force` with no snapshot.
- No dry-run, no non-interactive mode, no log file, no tests, no shellcheck.

## Design principles

1. Safe by default: nothing destructive, nothing that changes the host's network
   identity, and no OS package upgrade unless asked.
2. Everything that mutates goes through one `run` helper so `--dry-run` can print
   every command and write nothing.
3. Every external download is verified (pinned version plus checksum or signed
   repository) before it runs. No `curl | sh`.
4. Idempotent: re-running a step on a configured host changes nothing.
5. One source of versions: `bin/prod/host-setup.versions`.
6. Generic baseline in the gem, BTS fleet layer as a sourced extension.

## Steps

`--step=NAME` runs only that step. `--from-step=NAME` runs that step and every step
after it (the old `--step` resume behavior). Without either, the default list runs in
order. `--skip=NAME[,NAME]` omits steps from the list.

| Step | Default | What it does |
|------|---------|--------------|
| `welcome` | yes | Banner and overview (skipped with `--yes`). |
| `specs` | yes | Reports CPU, RAM, disk, architecture; warns below 4 cores or 4 GB. |
| `os_check` | yes | Verifies a supported OS and architecture; stops otherwise. |
| `network` | only with `--static-ip-eth`, `--static-ip-wlan` or `--disable-wifi` | Raspberry Pi network changes. |
| `tweaks` | only with `--disable-bluetooth` or `--mute-audio` | Raspberry Pi hardware tweaks. |
| `hardening` | yes | ssh key-only, fail2ban, unattended-upgrades (security only), ufw. |
| `backup` | yes | Installs the pinned borg client; no repository is configured. |
| `update` | yes | `apt-get update` only. Package upgrades need `--update-os`. |
| `docker` | yes | Docker Engine from Docker's signed apt repository. |
| `dokku` | yes | Dokku at the manifest tag, plus plugins at manifest tags. |
| `hostname` | only with `--hostname` | Sets the hostname. |
| `storage` | yes | Storage backend choice (Garage or AWS), mount path. |
| `community_engine` | yes | Creates the app, Postgres/PostGIS and Redis services, domain, certificate. |
| `elasticsearch` | no | Installs the Elasticsearch plugin. Only with `--with-elasticsearch`. |
| `cloudflared` | no | Cloudflare tunnel client. Only with `--with-cloudflared`. |
| `nordvpn` | no | NordVPN client. Only with `--with-nordvpn`. |
| `fleet_baseline` | no | BTS fleet layer through the extension hook. Only with `--with-fleet-baseline`. |

Behavior change to call out in release notes: `cloudflared` and `nordvpn` are no
longer in the default list; `elasticsearch` is no longer installed with the plugins.

## Flags

Existing flags keep their names: `--static-ip-eth=`, `--static-ip-wlan=`,
`--disable-wifi`, `--disable-bluetooth`, `--mute-audio`, `--docker-version=`,
`--nordvpn-login-url=`, `--hostname=`, `--storage-path=`, `-v/--verbose`,
`--step=`, `--help`.

New flags:

| Flag | Meaning |
|------|---------|
| `--with-elasticsearch` | Enable the `elasticsearch` step (H3). |
| `--with-cloudflared`, `--with-nordvpn` | Enable those steps (H4). |
| `--with-fleet-baseline` | Enable `fleet_baseline`; needs `--fleet-extension=FILE` (H4). |
| `--fleet-extension=FILE` | Path to the sourced BTS extension (H4). |
| `--storage-backend=garage\|aws\|local` | Storage choice (H4); default `local`. |
| `--update-os` | Allow `apt-get upgrade` in the `update` step (H5). |
| `--dry-run` | Print every command, write nothing (H5). |
| `--yes` | Non-interactive; every prompt takes its default or its explicit flag (H5). |
| `--skip=` | Omit steps (H5). |
| `--log-file=PATH` | Log location, default `/var/log/ce-host-setup.log` (H5). |
| `--force` | Needed, with a typed confirmation, to act on a host that has live apps (H5). |
| `--recreate-service=NAME` | Recreate one named service after a snapshot (H5). Replaces the old "recreate" prompt. |
| `--app=NAME`, `--domain=HOST`, `--letsencrypt-email=ADDR` | Inputs for the `community_engine` step; with `--yes` a missing one skips that sub-step. |
| `--dokku-domain=HOST`, `--dokku-ssh-key-file=FILE` | Global Dokku domain and the admin key to register. |
| `--confirm-destroy=NAME` | The typed confirmation for `--recreate-service` when `--yes` is set. |
| `--skip-firewall` | Leave the firewall alone (implied by `--with-fleet-baseline`). |
| `--fail2ban-ignoreip=LIST` | Addresses fail2ban must never ban. |
| `--s3-endpoint=`, `--s3-bucket=`, `--s3-region=` | Storage settings; keys are never handled by the script. |
| `--versions-file=PATH` | Use another manifest. |

## Version manifest (H2)

`bin/prod/host-setup.versions` is a plain `KEY=value` file (no shell code) read by the
script and by the BTS provisioning scripts. Keys:

`DOKKU_TAG`, `DOKKU_POSTGRES_TAG`, `DOKKU_REDIS_TAG`, `DOKKU_LETSENCRYPT_TAG`,
`DOKKU_ELASTICSEARCH_TAG`, `POSTGIS_IMAGE`, `POSTGIS_IMAGE_VERSION`, `REDIS_IMAGE`,
`REDIS_IMAGE_VERSION`, `ELASTICSEARCH_IMAGE_VERSION`, `DOCKER_ENGINE_VERSION`,
`CLOUDFLARED_VERSION`, `BORG_VERSION`.

Each key has a comment above it with the source URL and the date it was checked.
Updating a pin is a deliberate pull request; the script never follows `latest`.

## Supported platforms

Debian 12 and 13; Ubuntu 22.04, 24.04 and 26.04; architectures amd64 and arm64 (Dokku
supports Ubuntu 22.04/24.04/26.04 and Debian 11+; Docker's Debian page lists 12 and 13,
and the Docker repository for Ubuntu 26.04 is unverified). The
`os_check` step reads `/etc/os-release`, chooses the matching Docker apt repository
(`debian` or `ubuntu`), and refuses anything else.

## Safety model

- Safety tiers follow the BTS `AGENTS.md`: production hosts are T3 and the script is
  only run there after a plan review. Dry-run output is the plan.
- Destructive actions (destroying an app, database or Redis service) are never part of
  a default run. They need `--recreate-service=NAME`, `--force` and a typed
  confirmation, and a snapshot step (`postgres:export`, `redis:export`) must succeed first.
- Hardening never locks the operator out: ssh key-only is applied only after the
  invoking user has at least one authorized key, and ufw allows ssh before enabling.
- The interrupt trap exits non-zero (130 for SIGINT).
- Logging never records secrets: prompted secrets are read with `read -s`, never
  echoed or passed on a command line.

## Gem versus BTS fleet layer

Generic baseline (gem): OS check, update policy, Docker, Dokku and plugins, ufw,
fail2ban, unattended-upgrades, ssh hardening, borg client, Garage/AWS storage
settings, app and service creation.

BTS fleet layer (management repository, sourced through `--fleet-extension`): the
managed firewall profile (`host_firewall_policy.sh`), the Pangolin exemption service
on hosts that run both Pangolin and Headscale/Tailscale, node-exporter, Alloy, Borg
repositories and schedules, and the Garage client keys. The extension defines one
function, `fleet_baseline_run`, which calls the existing management scripts instead
of copying them. It must honor `DRY_RUN`.

## Tests (H5)

- shellcheck clean (`shellcheck -x bin/prod/host-setup.sh`).
- bats tests in `spec/scripts/host_setup/` for argument parsing, step selection,
  default list contents (Elasticsearch, Cloudflared, NordVPN absent), manifest
  parsing, and dry-run output (no mutating command executes).
- Integration check in a throwaway container or VM, never on a fleet host.

## Placement and use

- Canonical copy: `bin/prod/host-setup.sh` with `bin/prod/host-setup.versions` in this
  gem. The two files travel together; `--versions-file` points at another manifest.
- Host apps: the Community Engine install generator (planned, Track K5) offers to copy
  both files into the host app's `bin/prod/`, so a solo host app carries them. The
  generator must copy the pair, never the script alone, and must not rewrite them.
  Until that exists, copy them by hand from the gem release you deploy.
- Runbook step 1 ("prepare the host"): run `--dry-run --yes` with the intended flags,
  review the output, then run it for real. On an existing server, step 1 is instead
  "verify the host meets the baseline": compare `dokku version`, `dokku plugin:list`,
  `ufw status` and the manifest.
- Where the manual commands live: [Deployment (Dokku)](./deployment-dokku.md).

## Out of scope

Ruby, Node and application dependencies (the Dockerfile owns those); DNS and edge
routing; creating Garage buckets and keys (see the per-client bucket provisioning
procedure); anything that changes a production app's configuration.

## Review checklist for each follow-up pull request

- Default `--dry-run` output shows no destructive command.
- No new unpinned download or `latest` tag.
- Elasticsearch, Cloudflared, NordVPN stay off by default.
- Comments in the script are at most five lines; rationale goes in the commit.
