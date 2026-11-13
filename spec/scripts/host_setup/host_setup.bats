#!/usr/bin/env bats
# Tests for bin/prod/host-setup.sh: argument parsing, step selection, manifest
# parsing and dry-run behavior. Nothing here mutates the host: every run is a
# dry run or a sourced function call.

SCRIPT="${BATS_TEST_DIRNAME}/../../../bin/prod/host-setup.sh"
VERSIONS="${BATS_TEST_DIRNAME}/../../../bin/prod/host-setup.versions"

# Prints the step list the script would use for the given flags.
steps_for() {
  bash -c 'source "$1"; shift; parse_args "$@"; build_step_list; echo "${ALL_STEPS[*]}"' _ "$SCRIPT" "$@"
}

supported_os() {
  bash -c 'source "$1"; detect_os' _ "$SCRIPT" >/dev/null 2>&1
}

@test "--help exits 0 and documents the safety flags" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--yes"* ]]
  [[ "$output" == *"--recreate-service"* ]]
  [[ "$output" == *"--update-os"* ]]
  [[ "$output" == *"--with-elasticsearch"* ]]
}

@test "an unknown option exits 2" {
  run bash "$SCRIPT" --nonsense
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "default steps leave out elasticsearch, cloudflared, nordvpn and fleet_baseline" {
  run steps_for
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku"* ]]
  [[ "$output" != *"elasticsearch"* ]]
  [[ "$output" != *"cloudflared"* ]]
  [[ "$output" != *"nordvpn"* ]]
  [[ "$output" != *"fleet_baseline"* ]]
  [[ "$output" != *"network"* ]]
}

@test "opt-in flags add their steps" {
  run steps_for --with-elasticsearch --with-cloudflared --with-nordvpn --with-fleet-baseline
  [[ "$output" == *"elasticsearch"* ]]
  [[ "$output" == *"cloudflared"* ]]
  [[ "$output" == *"nordvpn"* ]]
  [[ "$output" == *"fleet_baseline"* ]]
}

@test "network and tweaks appear only with their flags" {
  run steps_for --static-ip-eth=192.0.2.5/24 --mute-audio
  [[ "$output" == *"network"* ]]
  [[ "$output" == *"tweaks"* ]]
}

@test "--skip removes steps" {
  run steps_for --skip=hardening,docker
  [[ "$output" != *"hardening"* ]]
  [[ "$output" != *"docker"* ]]
  [[ "$output" == *"dokku"* ]]
}

@test "an unknown --step fails" {
  run bash "$SCRIPT" --dry-run --yes --step=bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown step"* ]]
}

@test "the shipped manifest loads and has no latest tags" {
  run bash -c 'source "$1"; VERSIONS_FILE="$2"; load_versions; echo "$DOKKU_TAG $POSTGIS_IMAGE_VERSION"' _ "$SCRIPT" "$VERSIONS"
  [ "$status" -eq 0 ]
  [[ "$output" == v0.* ]]
  ! grep -q "=latest" "$VERSIONS"
}

@test "a manifest line with shell syntax is rejected" {
  f="${BATS_TEST_TMPDIR}/m.versions"
  cp "$VERSIONS" "$f"
  echo 'DOKKU_TAG=$(touch pwned)' >> "$f"
  run bash -c 'source "$1"; VERSIONS_FILE="$2"; load_versions' _ "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid line"* ]]
  [ ! -e pwned ]
}

@test "an unknown manifest key is rejected" {
  f="${BATS_TEST_TMPDIR}/m.versions"
  cp "$VERSIONS" "$f"
  echo 'SURPRISE=1' >> "$f"
  run bash -c 'source "$1"; VERSIONS_FILE="$2"; load_versions' _ "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown manifest key"* ]]
}

@test "a missing manifest key is rejected" {
  f="${BATS_TEST_TMPDIR}/m.versions"
  grep -v '^BORG_VERSION=' "$VERSIONS" > "$f"
  run bash -c 'source "$1"; VERSIONS_FILE="$2"; load_versions' _ "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BORG_VERSION"* ]]
}

@test "dry run prints commands and writes no log file" {
  supported_os || skip "host OS is not a supported target"
  log="${BATS_TEST_TMPDIR}/run.log"
  run bash "$SCRIPT" --dry-run --yes --log-file="$log" --skip=specs
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"[dry-run] apt-get update"* ]]
  [[ "$output" == *"[dry-run] ufw default deny incoming"* ]]
  [ ! -e "$log" ]
}

@test "dry run never upgrades packages without --update-os" {
  supported_os || skip "host OS is not a supported target"
  run bash "$SCRIPT" --dry-run --yes --step=update
  [ "$status" -eq 0 ]
  [[ "$output" != *"apt-get upgrade"* ]]
  run bash "$SCRIPT" --dry-run --yes --step=update --update-os
  [[ "$output" == *"apt-get upgrade"* ]]
}

@test "dry run leaves out elasticsearch, cloudflared and nordvpn by default" {
  supported_os || skip "host OS is not a supported target"
  run bash "$SCRIPT" --dry-run --yes --skip=specs
  [[ "$output" != *"elasticsearch"* ]]
  [[ "$output" != *"cloudflared"* ]]
  [[ "$output" != *"nordvpn"* ]]
}

@test "dry run with --with-elasticsearch names the plugin step" {
  supported_os || skip "host OS is not a supported target"
  run bash "$SCRIPT" --dry-run --yes --step=elasticsearch
  [ "$status" -eq 0 ]
  [[ "$output" == *"dokku-elasticsearch.git --committish 2.7.0"* ]]
  [[ "$output" == *"SEARCH_BACKEND=elasticsearch"* ]]
}

@test "recreating a service without --force is refused" {
  run bash -c 'source "$1"; FORCE=false; confirm_destroy mydb' _ "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--force"* ]]
}

@test "recreating a service needs the typed confirmation to match" {
  run bash -c 'source "$1"; FORCE=true YES=true CONFIRM_DESTROY=wrong; confirm_destroy mydb' _ "$SCRIPT"
  [ "$status" -eq 1 ]
  run bash -c 'source "$1"; FORCE=true YES=true CONFIRM_DESTROY=mydb; confirm_destroy mydb' _ "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "an empty snapshot stops the recreate" {
  d="${BATS_TEST_TMPDIR}/snap"
  run bash -c 'source "$1"; SNAPSHOT_DIR="$2"; dokku() { :; }; snapshot_service postgres mydb' _ "$SCRIPT" "$d"
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty"* ]]
}

@test "SIGINT exits non-zero" {
  run bash -c 'source "$1"; kill -INT $$; sleep 1' _ "$SCRIPT"
  [ "$status" -eq 130 ]
}

@test "the fleet extension must be root-owned and not world writable" {
  ext="${BATS_TEST_TMPDIR}/ext.sh"
  echo 'fleet_baseline_run() { echo ran; }' > "$ext"
  chmod 666 "$ext"
  run bash -c 'source "$1"; FLEET_EXTENSION="$2"; step_fleet_baseline' _ "$SCRIPT" "$ext"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing"* ]]
}

@test "garage storage needs a bucket and an endpoint" {
  run bash -c 'source "$1"; DRY_RUN=true STORAGE_BACKEND=garage configure_app_storage demo' _ "$SCRIPT"
  [ "$status" -eq 1 ]
  run bash -c 'source "$1"; DRY_RUN=true STORAGE_BACKEND=garage S3_BUCKET_ARG=b S3_ENDPOINT_ARG=http://garage:3900 configure_app_storage demo' _ "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AWS_REQUEST_CHECKSUM_CALCULATION=when_required"* ]]
  [[ "$output" == *"ACTIVE_STORAGE_ROUTE=proxy"* ]]
}

@test "no curl-pipe-shell, eval, latest tags or bare sudo remain" {
  ! grep -nE 'curl[^|]*\| *(ba)?sh|wget[^|]*\| *(ba)?sh|sh <\(curl' "$SCRIPT"
  ! grep -nE '(^|[^a-z_])eval ' "$SCRIPT"
  ! grep -nE 'image-version latest|--image-version "?latest' "$SCRIPT"
  ! grep -nE '^\s*sudo ' "$SCRIPT"
  ! grep -nE 'apps:destroy' "$SCRIPT"
}
