Sidekiq Scheduler Configuration

This repository includes a `config/sidekiq_scheduler.yml` file with scheduled jobs for
use with the `sidekiq-scheduler` gem. The file currently defines:

- `better_together:metrics:link_checker_weekly` — runs
  `BetterTogether::Metrics::LinkCheckerReportSchedulerJob` weekly (Mondays) at 02:00 UTC on
  the `metrics` queue. The job will call the report generator and email the
  generated report to the application's default `from` address only if there are
  new broken links or changes since the last report.
- `better_together:event_reminder_scan_hourly` — runs
  `BetterTogether::EventReminderScanJob` hourly on the `notifications` queue to
  scan upcoming events and schedule per-event reminders.

How to enable

1. Add `gem 'sidekiq-scheduler'` to your Gemfile (if not already present) and run
   `bundle install`.
2. In your Sidekiq initializer (for example `config/initializers/sidekiq.rb`),
   load the schedule on boot:

```ruby
# config/initializers/sidekiq_scheduler.rb
# Note: The engine already provides this initializer which merges
# schedules from both the engine and host app. You typically don't
# need to create this file unless you want custom loading logic.
#
# The engine's initializer loads schedules from:
# - BetterTogether::Engine.root/config/sidekiq_scheduler.yml (base)
# - Rails.root/config/sidekiq_scheduler.yml (overrides)
#
# See config/initializers/sidekiq_scheduler.rb in the engine for details.
```

3. Ensure your Sidekiq process is started in server mode (not only client). In
   Docker/compose setups, run the Sidekiq container with the application code
   and environment variables as usual.

Notes

- The cron times in `sidekiq_scheduler.yml` are interpreted by the host running
  Sidekiq. All times are in UTC.
- The engine provides a base schedule. Host apps can override or disable engine
  jobs by creating their own `config/sidekiq_scheduler.yml` with matching job names.
- To disable a job: set `enabled: false` in your host app's schedule file.
- To modify a schedule: override the `cron` value in your host app's schedule file.
- Jobs can also be triggered manually via rake tasks (e.g., `rake better_together:metrics:link_checker_weekly`).
