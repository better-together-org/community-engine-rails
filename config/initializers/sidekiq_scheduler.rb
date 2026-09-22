# frozen_string_literal: true

# Load Sidekiq Scheduler schedule file when Sidekiq server starts.
# Merges schedules from the core engine, any bundled extension engines (e.g.
# better_together-borgberry), and the host app, in that order — so extension
# gems can ship their own scheduled jobs without core CE knowing about them,
# and a host app can still override or disable any job by name.
#
# Host apps can override or disable engine jobs by creating their own
# config/sidekiq_scheduler.yml with matching job names. For example:
#
#   # config/sidekiq_scheduler.yml (in host app)
#   "better_together:metrics:link_checker_daily":
#     enabled: false  # Disables the engine's link checker job
#
#   "better_together:event_reminder_scan_hourly":
#     cron: '0 */2 * * *'  # Override to run every 2 hours instead of hourly
#
if defined?(Sidekiq) && Sidekiq.server?
  merged_schedule = {}

  merge_schedule_file = lambda do |schedule_file, source_label|
    next unless schedule_file.exist?

    begin
      merged_schedule.merge!(YAML.load(schedule_file.read) || {})
      Rails.logger.info "Loaded #{source_label} Sidekiq Scheduler from #{schedule_file}"
    rescue StandardError => e
      Rails.logger.error "Failed to load #{source_label} Sidekiq Scheduler: #{e.message}"
    end
  end

  # Load core engine's schedule first (base schedule)
  merge_schedule_file.call(BetterTogether::Engine.root.join('config', 'sidekiq_scheduler.yml'), 'Community Engine')

  # Load any bundled extension engine's schedule next (e.g. better_together-borgberry),
  # sorted by engine name for deterministic merge order across boots.
  Rails::Engine.descendants
               .reject { |engine| engine == BetterTogether::Engine || engine <= Rails::Application }
               .sort_by(&:engine_name)
               .each do |engine|
    merge_schedule_file.call(engine.root.join('config', 'sidekiq_scheduler.yml'), engine.engine_name)
  end

  # Load host app's schedule last (overrides engine/extension schedules for same job names)
  merge_schedule_file.call(Rails.root.join('config', 'sidekiq_scheduler.yml'), 'host app')

  # Set the merged schedule
  if merged_schedule.any?
    Sidekiq.schedule = merged_schedule
    Sidekiq::Scheduler.reload_schedule!
    Rails.logger.info "Loaded #{merged_schedule.keys.count} scheduled job(s): #{merged_schedule.keys.join(', ')}"
  else
    Rails.logger.warn 'No Sidekiq Scheduler jobs found in engine or host app'
  end
end
