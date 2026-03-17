# Rails Version Branch Maintenance

This project maintains one current Rails line on `main` and separate compatibility branches for older or forward-looking Rails lines.

## Branch Model

- `main`: latest fully working Rails line
- `compat/rails-7.2`: maintained compatibility branch for Rails 7.2
- `compat/rails-8.0`: maintained compatibility branch for Rails 8.0
- `compat/rails-8.1`: maintained compatibility branch for Rails 8.1

Current workflow defaults:

- `main` and `compat/rails-8.0` use Rails `8.0.3`
- `compat/rails-7.2` uses Rails `7.2.2.2`
- `compat/rails-8.1` uses Rails `8.1.2`

## CI Model

GitHub Actions is split into two layers:

1. Branch-native required CI
- Runs the branch's native Rails lane
- Required checks are `rspec`, `rubocop`, `i18n-health`, and `security`
- This is the merge gate for normal PRs

2. Targeted and advisory workflows
- `Dependency Compatibility Validation` runs only on PRs that change `sidekiq` or `connection_pool`
- `Compat Branch Sync PRs` opens maintenance PRs from `main` into each compatibility branch

The branch-native workflow intentionally does not run special `sidekiq` or `connection_pool` checks on every PR. Those checks are reserved for the dependency PRs that need them.

## Dependabot Strategy

Dependabot is configured separately for:

- `main`
- `compat/rails-7.2`
- `compat/rails-8.0`
- `compat/rails-8.1`

This keeps dependency PRs aligned with the branch they actually target.

Branch-specific policy:

- `compat/rails-7.2` ignores `sidekiq >= 8.1.0`
- `connection_pool 3.x` may be evaluated on all maintained branches
- `sidekiq 8.1.x` may be evaluated on `main`, `compat/rails-8.0`, and `compat/rails-8.1`

## Maintenance Procedure

1. Land product and security changes on `main`
2. Let the sync workflow open PRs from `main` into each `compat/*` branch
3. Resolve Rails-specific or dependency-specific conflicts on the target compatibility branch
4. Merge green sync PRs regularly so older lines keep receiving fixes
5. Review branch-targeted Dependabot PRs against the target branch's native Rails lane

## Dependency Incident Policy

The historic `connection_pool 3.x` API concern is treated as resolved upstream in Sidekiq. Special validation remains in place only for the individual `sidekiq` and `connection_pool` PRs so those updates can be confirmed without adding cost to every CI run.
