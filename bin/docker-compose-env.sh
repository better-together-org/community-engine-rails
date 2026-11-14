#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_basename="$(basename "$repo_root")"
git_dir="$(git -C "$repo_root" rev-parse --absolute-git-dir 2>/dev/null || printf '%s/.git' "$repo_root")"
git_common_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || printf '%s' "$git_dir")"

# Community Engine's compose stack uses fixed service/container/volume names for the
# shared dev database, Redis, and Elasticsearch services. Secondary git worktrees
# must reuse the primary compose project instead of inventing a per-worktree one,
# otherwise `bin/dc-run` cannot resolve `db`/`redis` and conflicts on fixed names.
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-community-engine-rails}"

sanitize_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

if [[ "$git_dir" == "$git_common_dir" ]]; then
  worktree_db_suffix=""
else
  worktree_db_suffix="_$(sanitize_slug "$repo_basename")"
fi

export DC_UID="${DC_UID:-$(id -u)}"
export DC_GID="${DC_GID:-$(id -g)}"
export CE_WORKTREE_DB_SUFFIX="${CE_WORKTREE_DB_SUFFIX:-$worktree_db_suffix}"
export DB_HOST="${DB_HOST:-db}"
export DB_PORT="${DB_PORT:-5432}"
export DB_USERNAME="${DB_USERNAME:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-postgres}"
export SEARCH_BACKEND="${SEARCH_BACKEND:-pg_search}"
export REDIS_URL="${REDIS_URL:-redis://redis:6379}"
export RACK_ATTACK_REDIS_URL="${RACK_ATTACK_REDIS_URL:-redis://redis-rack-attack:6379}"
export RACK_ATTACK_REDIS_POOL_SIZE="${RACK_ATTACK_REDIS_POOL_SIZE:-5}"
export RACK_ATTACK_REDIS_POOL_TIMEOUT="${RACK_ATTACK_REDIS_POOL_TIMEOUT:-5}"

# prspec worker count. Default: a quarter of the host cores, between 2 and 4 (a 12-core machine gets 3).
# Eight workers on bts-0 measured fastest but peaked near 16 GiB and 600% CPU, which starved the host's other
# services and ended in out-of-memory kills. Override with WORKERS=N when the host is otherwise idle. The
# container is also capped (CE_TEST_CPUS, CE_TEST_MEM_LIMIT in docker-compose.yml). Databases for N workers
# are created on demand by bin/dc-prepare-worktree-test-dbs.
if [[ -z "${WORKERS:-}" ]]; then
  detected_cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
  default_workers=$(( detected_cores / 4 ))
  (( default_workers < 2 )) && default_workers=2
  (( default_workers > 4 )) && default_workers=4
  export WORKERS="$default_workers"
else
  export WORKERS
fi
