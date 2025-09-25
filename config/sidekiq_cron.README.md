Sidekiq Cron schedules

This repository includes a `config/sidekiq_cron.yml` file with scheduled jobs for
use with the `sidekiq-cron` gem. The file currently defines:

- `better_together:link_checker_report_daily` — runs
  `BetterTogether::Metrics::LinkCheckerReportSchedulerJob` daily at 02:00 UTC on
  the `metrics` queue. The job will call the report generator and email the
  generated report to the application's default `from` address.

How to enable

1. Add `gem 'sidekiq-cron'` to your Gemfile (if not already present) and run
   `bundle install`.
2. In your Sidekiq initializer (for example `config/initializers/sidekiq.rb`),
   load the schedule on boot:

```ruby
# config/initializers/sidekiq.rb
if defined?(Sidekiq) && Sidekiq.server?
  schedule_file = Rails.root.join('config', 'sidekiq_cron.yml')
  if schedule_file.exist?
    Sidekiq::Cron::Job.load_from_hash YAML.safe_load(schedule_file.read)
  end
end
```

3. Ensure your Sidekiq process is started in server mode (not only client). In
   Docker/compose setups, run the Sidekiq container with the application code
   and environment variables as usual.

Notes

- The cron times in `sidekiq_cron.yml` are interpreted by the host running
  Sidekiq. Use UTC or adjust the times to your preferred timezone.
- Alternatively you can keep the existing `lib/tasks`/`whenever` approach; this
  file is provided so Sidekiq-based scheduling is available as an option.
