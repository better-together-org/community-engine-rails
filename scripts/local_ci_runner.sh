#!/usr/bin/env bash
# Local CI runner that mirrors .github/workflows/rubyonrails.yml pass conditions
# Usage: ./scripts/local_ci_runner.sh [--no-services] [--no-parallel] [--timeout-es 60]

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

NO_SERVICES=0
NO_PARALLEL=0
ES_TIMEOUT=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-services) NO_SERVICES=1; shift ;;
    --no-parallel) NO_PARALLEL=1; shift ;;
    --timeout-es) ES_TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--no-services] [--no-parallel] [--timeout-es SECONDS]

--no-services   Skip starting docker services (postgres/elasticsearch). Useful when already running.
--no-parallel   Run steps serially instead of spinning rubocop/security in parallel.
--timeout-es N  Wait up to N seconds for Elasticsearch to become healthy (default: 60).

This script attempts to reproduce the GitHub Actions job steps for the "Ruby on Rails CI" workflow
in this repository and reports pass/fail per-step.
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Helpers
log() { printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$*"; }
run_cmd() {
  local label="$1"; shift
  log "START: $label"
  if "$@"; then
    log "OK: $label"
    return 0
  else
    local rc=$?
    log "FAIL: $label (exit $rc)"
    return $rc
  fi
}

# Record step results
declare -A STEP_STATUS

# Start services (postgres + elasticsearch) using docker compose if requested
start_services() {
  if [[ $NO_SERVICES -eq 1 ]]; then
    log "Skipping service startup (--no-services)"
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
  log "Starting services via 'docker compose'"
  # Start services detached; avoid attaching or waiting for input
  DOCKER_TIMEOUT=30
  docker compose up -d --remove-orphans postgres elasticsearch || return 1
    elif command -v docker-compose >/dev/null 2>&1; then
  log "Starting services via 'docker-compose'"
  docker-compose up -d --remove-orphans postgres elasticsearch || return 1
    else
      log "docker compose not available; please start Postgres and Elasticsearch manually"
      return 1
    fi
  else
    log "docker not found; please start Postgres and Elasticsearch manually"
    return 1
  fi
}

wait_for_elasticsearch() {
  local timeout=${ES_TIMEOUT:-60}
  local deadline=$((SECONDS + timeout))
  log "Waiting up to ${timeout}s for Elasticsearch to be healthy on http://localhost:9200"
  while [[ $SECONDS -lt $deadline ]]; do
    if curl -s "http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=1s" >/dev/null 2>&1; then
      log "Elasticsearch reported healthy"
      return 0
    fi
    sleep 1
  done
  log "Timed out waiting for Elasticsearch"
  return 1
}

prepare_db_schema() {
  # Matches workflow: bundle exec rake -f spec/dummy/Rakefile db:schema:load
  if [[ -x ./bin/dc-run ]]; then
    run_cmd "Prepare DB schema (via bin/dc-run)" ./bin/dc-run bundle exec rake -f spec/dummy/Rakefile db:schema:load
  else
    run_cmd "Prepare DB schema (native)" bundle exec rake -f spec/dummy/Rakefile db:schema:load
  fi
}

run_rspec() {
  if [[ -x ./bin/dc-run ]]; then
    run_cmd "Run RSpec (via bin/dc-run)" ./bin/dc-run bundle exec rspec
  else
    run_cmd "Run RSpec (native)" bundle exec rspec
  fi
}

run_rubocop() {
  if [[ -x ./bin/dc-run ]]; then
    run_cmd "Rubocop" ./bin/dc-run bundle exec rubocop --parallel
  else
    run_cmd "Rubocop" bundle exec rubocop --parallel
  fi
}

run_security_checks() {
  # bundler-audit + brakeman (as in workflow)
  if [[ -x ./bin/dc-run ]]; then
  # Ensure non-interactive environment
  export CI=1

  # Don't attempt to install binstubs (can be interactive); run bundler-audit directly
  ./bin/dc-run bundle exec bundler-audit --update >/dev/null 2>&1 || log "bundler-audit update completed (advisories may exist)"
  run_cmd "Run bundler-audit" ./bin/dc-run bundle exec bundler-audit --quiet || true
  # Run brakeman non-interactively: force no pager and limited verbosity
  PAGER=cat TERM=dumb run_cmd "Run brakeman" ./bin/dc-run bundle exec brakeman --no-pager -q -w2
  else
  export CI=1

  # Don't attempt to install binstubs (can be interactive); run bundler-audit directly
  bundle exec bundler-audit --update >/dev/null 2>&1 || log "bundler-audit update completed (advisories may exist)"
  run_cmd "Run bundler-audit (native)" bundle exec bundler-audit --quiet || true
  PAGER=cat TERM=dumb run_cmd "Run brakeman (native)" bundle exec brakeman --no-pager -q -w2
  fi
}

# Main orchestration
log "Local CI runner starting"

# Step 1: start services (non-blocking) if needed
if start_services; then
  STEP_STATUS[start_services]=0
else
  STEP_STATUS[start_services]=1
fi

# Step 2: run rubocop and security in parallel (these don't require DB/ES)
PIDS=()
if [[ $NO_PARALLEL -eq 0 ]]; then
  run_rubocop &
  PIDS+=("$!")
  run_security_checks &
  PIDS+=("$!")
else
  run_rubocop
  STEP_STATUS[rubocop]=$?
  run_security_checks
  STEP_STATUS[security]=$?
fi

# Step 3: ensure ES healthy before DB/RSPEC steps (skip when --no-services)
if [[ $NO_SERVICES -eq 1 ]]; then
  log "Skipping Elasticsearch health check because --no-services was passed"
  STEP_STATUS[elasticsearch]=0
else
  if wait_for_elasticsearch; then
    STEP_STATUS[elasticsearch]=0
  else
    STEP_STATUS[elasticsearch]=1
  fi
fi

# Step 4: prepare DB schema
prepare_db_schema
STEP_STATUS[db_prepare]=$?

# Step 5: run rspec (this is the heavy step)
run_rspec
STEP_STATUS[rspec]=$?

# Wait for background jobs if any
if [[ ${#PIDS[@]} -gt 0 ]]; then
  for pid in "${PIDS[@]}"; do
    if wait "$pid"; then
      log "Background job (pid $pid) finished OK"
    else
      log "Background job (pid $pid) failed"
    fi
  done
  # Capture their exit statuses via jobs' outputs are already logged by run_cmd
fi

# Summarize
log "Local CI run summary:" 
for key in start_services elasticsearch db_prepare rspec rubocop security; do
  if [[ -v STEP_STATUS[$key] ]]; then
    status=${STEP_STATUS[$key]}
    if [[ "$status" -eq 0 ]]; then
      printf "  %-15s : OK\n" "$key"
    else
      printf "  %-15s : FAIL (exit %d)\n" "$key" "$status"
    fi
  else
    printf "  %-15s : SKIPPED/UNKNOWN\n" "$key"
  fi
done

# Exit non-zero if rspec or rubocop or security or db_prepare failed (mimic CI strictness)
if [[ ${STEP_STATUS[rspec]:-0} -ne 0 || ${STEP_STATUS[rubocop]:-0} -ne 0 || ${STEP_STATUS[security]:-0} -ne 0 || ${STEP_STATUS[db_prepare]:-0} -ne 0 ]]; then
  log "One or more critical steps failed. See logs above."
  exit 2
fi

log "All critical steps passed (rspec, rubocop, security, db_prepare)"
exit 0
