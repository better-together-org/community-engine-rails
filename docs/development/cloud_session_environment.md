# Cloud Agent Session Environment

How to run the dev and test environment inside a **Claude Code cloud session**
(claude.ai/code, or a GitHub-triggered agent run). These are ephemeral Linux
containers with an egress proxy, and the standard `bin/dc-*` Docker workflow
does not work in them as-is. Everything here was worked out by hand in such a
session. `bin/cloud-session-env` scripts the parts that work, so future
sessions don't need to work it out again.

> **TL;DR**
> ```bash
> bin/cloud-session-env setup     # ~3-5 min the first time
> bin/cloud-session-env run bundle exec prspec spec/path/to/file_spec.rb
> ```
> This is still `prspec`, as `CLAUDE.md` requires. Only the container it runs in
> differs from `bin/dc-run`.

## How to tell you are in one

- `$HTTPS_PROXY` points at `127.0.0.1:<port>`, and `/root/.ccr/` exists
  (`/root/.ccr/README.md` documents the proxy; check its state with
  `curl -sS "$HTTPS_PROXY/__agentproxy/status"`).
- You run as `root`, `docker` is installed, but `docker info` reports that no
  daemon is running.
- Host Ruby is older than `.ruby-version`, and Playwright's Chromium is
  preinstalled under `/opt/pw-browsers/`.

## What breaks in the standard workflow, and why

| Step | What happens | Cause |
| --- | --- | --- |
| `bin/dc-run …` | `Cannot connect to the Docker daemon` | dockerd isn't started in the container. Fix: `nohup dockerd &` (we are root). |
| Pulling `redis`, `postgis`, `ruby` images | `429 Too Many Requests` from registry-1.docker.io | The shared egress IP hits Docker Hub's anonymous rate limit. `mirror.gcr.io/library/<image>` serves official images; `imresamu/postgis` is **not** on the mirror and needs Docker Hub retries with backoff. |
| `docker build` of `Dockerfile.dev` (first `bin/dc-run`) | `apt-get update`: `Could not resolve 'deb.debian.org'` | Build containers get no DNS or proxy. Passing the proxy doesn't help: the proxy refuses Debian mirrors (HTTP 403, policy). **The dev image can't be built here.** |
| Native Ruby via `bin/install-ruby-version` / `rbenv install` | ruby-build has no definition for the pinned version, and then `cache.ruby-lang.org` returns 403 | Policy denial. The preinstalled ruby-build checkout also has no git remote (`git remote add origin https://github.com/rbenv/ruby-build.git` fixes the definitions, but the download still fails). |
| `git push` | `403 … Claude doesn't have GitHub access` | The Claude GitHub App isn't installed or linked for the org. Only a person can fix this (claude.ai GitHub connector / org app install). Commit locally and export a patch (`git format-patch`) so work isn't lost. |

What **does** work: Docker Hub and mirror pulls (with retries), rubygems.org
through the proxy, npm, and GitHub over git (when the app is installed).

## What `bin/cloud-session-env` does

1. **`services`**: starts `dockerd` if needed. Pulls every non-app image in
   `docker-compose.yml`, plus `ruby:<.ruby-version>`, with Docker Hub → mirror
   fallback and retries. Then runs `bin/dc-ensure-services`, which starts only
   `db` (5440), `redis` (6380) and `redis-rack-attack` (6381). None of those
   need the unbuildable app image.
2. **`run CMD…`**: the stand-in for `bin/dc-run`. Runs `CMD` in the official
   `ruby:<.ruby-version>` image (it already has build tools and `libpq-dev`) with:
   - `--network host`, so Postgres is `127.0.0.1:5440` and the egress proxy on
     `127.0.0.1` is reachable;
   - the proxy CA (`/root/.ccr/ca-bundle.crt`) mounted as `SSL_CERT_FILE` /
     `BUNDLE_SSL_CA_CERT`, plus the proxy env vars;
   - `DB_HOST`/`DB_PORT`/`REDIS_URL`/`RACK_ATTACK_REDIS_URL` pointed at the
     compose services;
   - gems in the named volume `ce-cloud-bundle`, so they persist between runs
     within a session.
3. **`bundle`**: `bundle install` in the runner (about 2 minutes on a cold volume).
4. **`db-setup`**: the equivalent of `bin/parallel-setup` (test DB plus
   `WORKERS` parallel DBs), plus `db:prepare` for the development DB, which the
   subsystem diagram exporter reads. **Re-run it after any migration or schema
   change**, as with `bin/parallel-setup`.
5. **`diagrams [file.mmd…]`**: the equivalent of `bin/export_schema_diagrams`.
   - Runs the stdlib-only DBML exporter on host Ruby (pinning `RBENV_VERSION`
     to an installed Ruby).
   - Renders with Playwright's Chromium (`CHROME_PATH`).
   - Runs `export_subsystem_diagrams.rb` in the runner.
   - Renders the changed (or named) Mermaid sources via `bin/render_diagrams`.

   Commit the regenerated files with any migration. The `Schema Diagrams` CI
   workflow fails without them.

`bin/render_diagrams` itself now pins its `npx` fallback to
`@mermaid-js/mermaid-cli@11`, because v12 removed the `-w`/`-H` flags the
script uses. When run as root it also passes a `--no-sandbox` puppeteer config
(`MERMAID_PUPPETEER_CONFIG`), since Chromium refuses to start as root
otherwise. In a cloud session, also set
`PUPPETEER_EXECUTABLE_PATH=/opt/pw-browsers/chromium-*/chrome-linux*/chrome`.
`diagrams` does that for you.

## Known gaps (environmental, not code failures)

The full suite **runs** (`bin/cloud-session-env run bundle exec prspec spec`;
about 10,000 examples, around 15 minutes with `WORKERS=8`), but these groups
fail for reasons the session can't fix. Report them as unverified rather
than as failures of the change.

| Group | Symptom | Why |
| --- | --- | --- |
| JS feature/system/acceptance specs (`spec/features`, `spec/system`, `spec/acceptance_criteria`, `js: true`) | `Selenium [:selenium_manager] error sending request for url (https://googlechromelabs.github.io/…)` | The runner image has no Chrome/chromedriver, and Selenium Manager can't download them. ~200 examples. |
| `spec/lib/better_together/capybara_screenshot_engine_spec.rb`, `screenshot_callout_processor_spec.rb` | Load error: `Could not open library 'libvips.so.42'` | No libvips in the runner, and apt is blocked. **These abort the whole run at load time**, so exclude them (below). |
| `spec/services/better_together/federation/transport/http_adapter_spec.rb` | `SSRFError: Could not resolve hostname 'example.com'` | The session has no direct DNS (only the proxy resolves names). |

Full-suite run without the two load-breaking files:

```bash
find spec -name '*_spec.rb' -not -path 'spec/dummy/*' \
  | grep -v -E 'capybara_screenshot_engine_spec|screenshot_callout_processor_spec' \
  | sort > tmp/cloud-session-specs.txt
WORKERS=8 bin/cloud-session-env db-setup
WORKERS=8 bin/cloud-session-env run bash -c 'bundle exec prspec $(cat tmp/cloud-session-specs.txt)' > tmp/full.log 2>&1
```

List the failing files, then check that every one is in the groups above:

```bash
grep -oE "^rspec '?\./spec/[^:' \[]+" tmp/full.log | sed -E "s/^rspec '?//" | sort | uniq -c
```

Anything outside `spec/features`, `spec/system`, `spec/acceptance_criteria` and
`http_adapter_spec.rb` is a real failure to investigate.

## Gotchas found along the way

- **`git stash` leaves untracked files behind.** Stashing to get a "before"
  baseline keeps a new, untracked migration while reverting `schema.rb`, so
  every spec dies with `PendingMigrationError`. Use a `git worktree` of the
  base commit instead, or `git stash -u`.
- **Files written by the runner are root-owned.** Harmless in the session
  (you are root), but don't copy that tree elsewhere expecting your UID.
- **Generated diagram files carry timestamps.** Re-running `diagrams`
  rewrites `ce_subsystem_inventory.{json,md}` with only a new
  `generated_at`. Revert those when nothing else changed.
- **Destroying a `Person` in a spec.** `create(:better_together_person)` and
  `create(:better_together_user, :confirmed).person` can't simply be
  `destroy!`ed: the protected primary community aborts it
  (`RecordNotDestroyed`, no errors), and a plain `person.destroy!` can raise
  `StaleObjectError` from deferred touches. For deletion behavior, extend
  `spec/services/better_together/person_hard_deletion_executor_spec.rb`, whose
  fixture already handles both.
