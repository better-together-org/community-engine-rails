#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET="scripts/session_command_log.sh"

if [[ -n "${BTS_MANAGEMENT_TOOL_ROOT:-}" ]] && [[ -x "${BTS_MANAGEMENT_TOOL_ROOT}/${TARGET}" ]]; then
  exec "${BTS_MANAGEMENT_TOOL_ROOT}/${TARGET}" "$@"
fi

SEARCH_DIR="${SCRIPT_DIR}"
for _ in 1 2 3 4 5 6 7 8; do
  for candidate in \
    "${SEARCH_DIR}/bts-cloud/n8n/management-tool" \
    "${SEARCH_DIR}/management-tool"
  do
    if [[ -x "${candidate}/${TARGET}" ]]; then
      exec "${candidate}/${TARGET}" "$@"
    fi
  done

  NEXT_DIR="$(dirname -- "${SEARCH_DIR}")"
  [[ "${NEXT_DIR}" == "${SEARCH_DIR}" ]] && break
  SEARCH_DIR="${NEXT_DIR}"
done

echo "Unable to locate management-tool root. Set BTS_MANAGEMENT_TOOL_ROOT." >&2
exit 1
