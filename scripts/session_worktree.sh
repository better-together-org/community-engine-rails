#!/usr/bin/env bash
set -euo pipefail

ROOT="${BTS_MANAGEMENT_TOOL_ROOT:-/home/rob/bts-cloud/n8n/management-tool}"
exec "${ROOT}/scripts/session_worktree.sh" "$@"
