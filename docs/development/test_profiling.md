# Test suite profiling and speed

How to find slow specs and what to expect from the suite. Numbers were measured on a 12-core
development machine (2026-10-08) running the full suite (9,532 examples) in Docker.

## Running faster locally

| Workers | Full suite (`Finished in`) | Notes |
|---|---|---|
| 4 (default) | 14 min 46 s | |
| 8 | **9 min 16 s** | best on 12 cores with other work running |
| 10 | 10 min 17 s | load average peaked near 37; Chrome-heavy specs oversubscribe the host |

(Before the 2026-10 speed fixes the same suite took about 37 min with 4 workers.)

```bash
WORKERS=8 bin/parallel-setup      # creates the worker databases for 8 workers (once per worker count)
WORKERS=8 bin/dc-ci               # full suite
WORKERS=8 bin/dc-run bundle exec prspec spec/requests
```

`WORKERS` is passed into the container through `docker-compose.yml` (default 4). Pick a count of
roughly two thirds of your cores; more workers than cores slows the run down.

## Profiling tools

`test-prof` is in the `:test` group and is inert unless one of its env vars is set. Profilers work
per process, so profile a small slice with plain `rspec` (this is an explicit exception to the
"prspec only" rule; do not use bare `rspec` for anything else):

```bash
mkdir -p tmp/profiles
# Where does time go: before hooks vs let vs the example body (per group)
bin/dc-run bash -c "RD_PROF=1 RD_PROF_TOP=15 bundle exec rspec spec/requests/better_together/events_controller_spec.rb"
# Which factories are created, how often, and how long they take
bin/dc-run bash -c "FPROF=1 FPROF_TOP=15 bundle exec rspec spec/requests/better_together/events_controller_spec.rb"
# Time spent in factory.create and SQL
bin/dc-run bash -c "EVENT_PROF=factory.create,sql.active_record EVENT_PROF_TOP=10 bundle exec rspec <files>"
# Sampling flame data (stackprof is already a dependency), then read it
bin/dc-run bash -c "TEST_STACK_PROF=1 TEST_STACK_PROF_MODE=wall bundle exec rspec <files>"
bin/dc-run bundle exec stackprof tmp/test_prof/stack-prof-report-wall-raw-total.dump --text --limit 40
```

The container writes `tmp/test_prof/` as root; remove it with sudo when you are done (it can reach
200 MB). In CI, `bin/ci-timing-summary` prints CPU time by directory, the per-example floor and
the 25 slowest examples to the job summary from the JSON results; run it locally on any
`rspec_results.json`.

Quick floor check: a request spec with `:as_user` and an empty body should take about 20 ms and a
model spec about 4 ms. If an empty example takes much longer, a global `before` hook regressed.

## What was slow and fixed (2026-10)

| Cause (found with RSpecDissect + StackProf) | Share of request-spec time | Fix |
|---|---|---|
| `Rails.application.reload_routes!` before every request/controller/feature example (its guard `mounted_helpers.respond_to?(:better_together)` is never true) | about 24% | reload once per worker; specs that `routes.draw` restore routes in an `after` hook |
| Auto-authentication did a real sign-in POST plus `follow_redirect!` page render | about 28% | Devise `sign_in`; tag `:real_login` for specs that need the real flow |
| Agreement-page re-link hook rebuilt seed data every example (its lookup used the wrong identifier, and earlier ran inside the rolled-back transaction) | about 9% (and 90 inserts/example before the first fix) | check through the agreement's page link, before `DatabaseCleaner.start` |
| Seed specs planted all ~196 countries (36-126 s each) | 7% of total CPU | `:reduced_geography` seeds 3 countries; one `:full_geography` example keeps the real dataset |
| `bin/dc-prepare-worktree-test-dbs` ran one `docker exec` per migration per database on every `dc-run prspec` | minutes of startup | one `psql` call per database (about 1 s) |

Request-spec slice (communities, events, platforms controller specs, one process): 179 s to 67 s.
Empty request example floor: 1.8 s to 0.02 s.

## Guidance for new specs

- Prefer `build`/`build_stubbed` or `let_it_be` (test-prof) over `create` when the spec only reads data.
- FactoryProf shows `better_together_event`, `better_together_user` and `better_together_community`
  at 50-120 ms per `create`; each pulls in a primary community, calendar, map and contact detail.
- Do not plant the full geography dataset unless the example is about that dataset.

## CI sharding

The `rspec` workflow job is split into 4 shard jobs (`rspec shard N/4`), each with its own
Postgres/Redis and 4 workers, plus an aggregate `rspec (3.4.10, <rails>)` job that requires every
shard, checks the merged example count and failures, merges SimpleCov results and publishes the
merged timing summary. Shards are balanced by recorded runtime, not file count:

```bash
bin/ci-spec-shards 2 4                      # spec files for shard 2 of 4
CI_SHARD_VERBOSE=1 bin/ci-spec-shards 1 4   # also prints each shard's weight to stderr
# Rebalance after a big change (use a full run's JSON, for example the CI artifact):
bin/ci-timing-summary --write-weights tmp/rspec_results.json > config/ci/spec_runtimes.json
```

Regenerate `config/ci/spec_runtimes.json` when a shard's wall time drifts more than about 25%
from the others (the per-shard job summaries show their timings). Files missing from the weights
file get the median weight.
