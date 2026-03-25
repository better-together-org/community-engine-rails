#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_basename="$(basename "$repo_root")"

sanitize_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

if [[ "$repo_basename" == "community-engine-rails" ]]; then
  worktree_db_suffix=""
else
  worktree_db_suffix="_$(sanitize_slug "$repo_basename")"
fi

export CE_WORKTREE_DB_SUFFIX="${CE_WORKTREE_DB_SUFFIX:-$worktree_db_suffix}"
export DB_HOST="${DB_HOST:-db}"
export DB_PORT="${DB_PORT:-5432}"
export DB_USERNAME="${DB_USERNAME:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-postgres}"
export ES_HOST="${ES_HOST:-http://elasticsearch:9200}"
export ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://elasticsearch:9200}"
export REDIS_URL="${REDIS_URL:-redis://redis:6379}"
export RACK_ATTACK_REDIS_URL="${RACK_ATTACK_REDIS_URL:-redis://redis-rack-attack:6379}"
export RACK_ATTACK_REDIS_POOL_SIZE="${RACK_ATTACK_REDIS_POOL_SIZE:-5}"
export RACK_ATTACK_REDIS_POOL_TIMEOUT="${RACK_ATTACK_REDIS_POOL_TIMEOUT:-5}"
