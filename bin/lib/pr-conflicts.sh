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
  # The runner has no git identity; a merge started without one can refuse to run.
  export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-pr-conflict-sweep}" GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-noreply@users.noreply.github.com}"
  export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}" GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"
  git -C "$scratch" merge --no-commit --no-ff "${REMOTE}/${base}" > "$scratch.log" 2>&1 || true
  if [ -z "$(git -C "$scratch" diff --name-only --diff-filter=U)" ]; then
    # Nothing unmerged: say why, so a merge that could not start is not mistaken for no conflict.
    tail -5 "$scratch.log" >&2
  fi
  rm -f "$scratch.log"
  git -C "$scratch" diff --name-only --diff-filter=U
  git -C "$scratch" merge --abort >/dev/null 2>&1 || true
  git worktree remove --force "$scratch"
  git update-ref -d "refs/sweep/pr-${number}"
}

