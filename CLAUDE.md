# CLAUDE.md — Community Engine Rails

Project instructions for Claude Code sessions in this repository.

@AGENTS.md

## Non-negotiable rules

- **Tests must use `prspec` (parallel rspec)**. Bare `rspec` is not permitted without explicit operator authorization. If `prspec` is unavailable, stop and report — do not fall back.
  - Targeted spec: `bin/dc-run bundle exec prspec spec/path/to/file_spec.rb`
  - Full suite (use sparingly, 13–18 min): `bin/dc-ci`
  - After any DB schema change: run `bin/parallel-setup` before running any tests
- **GitHub comments/PRs**: Use `gh_with_bts_robot.sh` — never bare `gh api graphql`. Posts as `bettertogether-bts-robot`, not `rsmithlal`. **Exception — opening a new PR:** `gh pr create` uses `rsmithlal` (human), not `bettertogether-bts-robot`, interim until a second BTS Robot GitHub account exists for authoring — GitHub blocks requesting a review from a PR's own author, so a bts-robot-opened PR could never have bts-robot assigned as an independent reviewer. Comments, reviews, and thread replies on that PR still post as `bettertogether-bts-robot` as normal.
- **Migrations**: Use `create_bt_table :name`, not `create_table :better_together_name`. Guard all additive migrations with `table_exists?`, `column_exists?`, `index_name_exists?`.
- **Run `bin/dc-ci` locally before pushing**. Full `bin/dc-ci` before any push that touches CI.
- **Never reference or ingest Colibri Software code** — proprietary third-party, no BTS relationship.
- **HAProxy routing changes require T3 full PR review**. DNS never changes.

## Test commands quick reference

| Goal | Command |
|------|---------|
| Run a single spec | `bin/dc-run bundle exec prspec spec/path/to/file_spec.rb` |
| Run a specific line | `bin/dc-run bundle exec prspec spec/path/to/file_spec.rb:123` |
| Run multiple files | `bin/dc-run bundle exec prspec spec/file1_spec.rb spec/file2_spec.rb` |
| Full suite | `bin/dc-ci` |
| Rebuild parallel DBs | `bin/parallel-setup` |
| Lint | `bin/dc-run bundle exec rubocop --parallel` |
| i18n check | `bin/dc-run bin/i18n` |
