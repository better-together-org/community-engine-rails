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
