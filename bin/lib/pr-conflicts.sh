# shellcheck shell=bash
# Shared by bin/ci-pr-conflict-sweep and bin/ci-resolve-generated-conflicts. Source it, do not run it.
# Needs: REMOTE (git remote name), ALLOWLIST (path of the generated-file globs), run from the repo root.

patterns=()
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  patterns+=("$line")
done < "$ALLOWLIST"

generated_only() {
  local file pattern matched
  for file in "$@"; do
    matched=0
    for pattern in "${patterns[@]}"; do
      # shellcheck disable=SC2053 # the pattern is meant to be a glob
      [[ "$file" == $pattern ]] && { matched=1; break; }
    done
    [ "$matched" = 1 ] || return 1
  done
}

# Names of the files a merge of the PR head into its base cannot resolve, one per line.
conflicted_files() {
  local number="$1" base="$2" scratch
  scratch="$(mktemp -d)"
  git fetch -q "$REMOTE" "$base" "+pull/${number}/head:refs/sweep/pr-${number}"
  git worktree add -q --detach "$scratch" "refs/sweep/pr-${number}"
  git -C "$scratch" merge --no-commit --no-ff "${REMOTE}/${base}" >/dev/null 2>&1 || true
  git -C "$scratch" diff --name-only --diff-filter=U
  git -C "$scratch" merge --abort >/dev/null 2>&1 || true
  git worktree remove --force "$scratch"
  git update-ref -d "refs/sweep/pr-${number}"
}

