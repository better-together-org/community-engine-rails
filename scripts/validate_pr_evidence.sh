#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/validate_pr_evidence.sh [--base-ref REF] [--head-ref REF] [--pr-body-file PATH]

Validate pull request evidence artifacts using the Community Engine tiered PR
evidence policy.
EOF
}

BASE_REF="${BASE_REF:-}"
HEAD_REF="${HEAD_REF:-HEAD}"
PR_BODY_FILE="${PR_BODY_FILE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      BASE_REF="$2"
      shift 2
      ;;
    --head-ref)
      HEAD_REF="$2"
      shift 2
      ;;
    --pr-body-file)
      PR_BODY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$BASE_REF" ]]; then
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    BASE_REF="origin/${GITHUB_BASE_REF}"
  else
    BASE_REF="refs/remotes/github/main"
  fi
fi

git rev-parse --verify "$BASE_REF" >/dev/null 2>&1 || { echo "error: base ref not found: $BASE_REF" >&2; exit 2; }
git rev-parse --verify "$HEAD_REF" >/dev/null 2>&1 || { echo "error: head ref not found: $HEAD_REF" >&2; exit 2; }

mapfile -t CHANGED_FILES < <(git diff --name-only "$BASE_REF...$HEAD_REF")
if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "No changed files detected between $BASE_REF and $HEAD_REF"
  exit 0
fi

has_changed() {
  local pattern="$1"
  local file
  for file in "${CHANGED_FILES[@]}"; do
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

all_changed_match() {
  local file
  for file in "${CHANGED_FILES[@]}"; do
    case "$file" in
      docs/*|.github/pull_request_template.md|scripts/validate_pr_evidence.sh)
        ;;
      *)
        return 1
        ;;
    esac
  done
  return 0
}

require_changed() {
  local pattern="$1"
  local message="$2"
  has_changed "$pattern" && return 0
  echo "error: $message" >&2
  return 1
}

require_any_changed() {
  local message="$1"
  shift
  local pattern
  for pattern in "$@"; do
    has_changed "$pattern" && return 0
  done
  echo "error: $message" >&2
  return 1
}

require_pr_body_section() {
  local heading="$1"
  local message="$2"

  [[ -n "$PR_BODY_FILE" ]] || return 0
  [[ -f "$PR_BODY_FILE" ]] || { echo "error: PR body file not found: $PR_BODY_FILE" >&2; return 1; }

  python3 - "$PR_BODY_FILE" "$heading" "$message" <<'PY'
from pathlib import Path
import re
import sys

body_path = Path(sys.argv[1])
heading = sys.argv[2]
message = sys.argv[3]
text = body_path.read_text(encoding="utf-8")
pattern = re.compile(rf"^##\s+{re.escape(heading)}\s*$", re.MULTILINE)
match = pattern.search(text)
if not match:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)

start = match.end()
next_match = re.search(r"^##\s+.+$", text[start:], re.MULTILINE)
section = text[start:start + next_match.start()] if next_match else text[start:]
if not re.search(r"\S", section):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)
PY
}

if all_changed_match; then
  TIER="docs-only"
elif has_changed 'app/views/*' || has_changed 'app/javascript/*' || has_changed 'app/assets/*' || has_changed 'spec/docs_screenshots/*'; then
  TIER="ui"
else
  TIER="backend"
fi

echo "Inferred PR evidence tier: $TIER"

FAILURES=0

require_pr_body_section 'Summary' 'PR body must include a populated Summary section' || FAILURES=$((FAILURES + 1))
require_pr_body_section 'Evidence Tier' 'PR body must include a populated Evidence Tier section' || FAILURES=$((FAILURES + 1))
require_pr_body_section 'Screenshots / Diagrams' 'PR body must include screenshot, diagram, changed-file, and spec coverage links' || FAILURES=$((FAILURES + 1))

case "$TIER" in
  docs-only)
    require_changed 'docs/*.md' 'docs-only PRs must update markdown documentation under docs/' || FAILURES=$((FAILURES + 1))
    if has_changed 'docs/diagrams/source/*.mmd'; then
      require_changed 'docs/diagrams/exports/png/*.png' 'diagram source changes require rendered PNG exports' || FAILURES=$((FAILURES + 1))
      require_changed 'docs/diagrams/exports/svg/*.svg' 'diagram source changes require rendered SVG exports' || FAILURES=$((FAILURES + 1))
    fi
    ;;
  backend)
    require_any_changed 'backend PRs must update docs describing changed behavior or architecture' \
      'docs/*.md' 'docs/developers/systems/*.md' 'docs/development/*.md' || FAILURES=$((FAILURES + 1))
    if has_changed 'db/migrate/*' || has_changed 'app/models/*' || has_changed 'app/controllers/*' || has_changed 'app/policies/*'; then
      require_any_changed 'core backend behavior changes should include or update a system/architecture diagram' \
        'docs/diagrams/source/*.mmd' 'docs/diagrams/exports/png/*.png' 'docs/diagrams/exports/svg/*.svg' || FAILURES=$((FAILURES + 1))
    fi
    ;;
  ui)
    require_any_changed 'UI PRs must update docs under docs/' \
      'docs/*.md' 'docs/developers/systems/*.md' 'docs/development/*.md' || FAILURES=$((FAILURES + 1))
    require_changed 'docs/diagrams/source/*.mmd' 'UI PRs must include at least one Mermaid flow diagram source' || FAILURES=$((FAILURES + 1))
    require_changed 'docs/diagrams/exports/png/*.png' 'UI PRs must include rendered PNG diagram exports' || FAILURES=$((FAILURES + 1))
    require_changed 'docs/diagrams/exports/svg/*.svg' 'UI PRs must include rendered SVG diagram exports' || FAILURES=$((FAILURES + 1))
    require_changed 'spec/docs_screenshots/*.rb' 'UI PRs must include a docs screenshot spec' || FAILURES=$((FAILURES + 1))
    require_changed 'docs/screenshots/desktop/*.png' 'UI PRs must include desktop screenshots' || FAILURES=$((FAILURES + 1))
    require_changed 'docs/screenshots/mobile/*.png' 'UI PRs must include mobile screenshots' || FAILURES=$((FAILURES + 1))
    ;;
esac

if [[ $FAILURES -ne 0 ]]; then
  echo "PR evidence validation failed with $FAILURES missing artifact group(s)." >&2
  exit 1
fi

echo "PR evidence validation passed."
