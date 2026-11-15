#!/usr/bin/env bash
# Forwarder. Every BTS worktree is created by the management-tool script so that all
# worktrees live in one place (/home/rob/bts-cloud/n8n/management-tool/tmp/worktrees) and are audited and pruned together.
set -euo pipefail
MT="${BTS_MANAGEMENT_TOOL:-/home/rob/bts-cloud/n8n/management-tool}"
[[ -x "${MT}/scripts/session_worktree.sh" ]] || { echo "error: ${MT}/scripts/session_worktree.sh not found" >&2; exit 2; }
exec "${MT}/scripts/session_worktree.sh" "$@"
