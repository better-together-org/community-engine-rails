# frozen_string_literal: true

# Load Sidekiq Scheduler schedule file when Sidekiq server starts.
# Merges schedules from both the engine and host app (if present).
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

  # Load engine's schedule first (base schedule)
  engine_schedule_file = BetterTogether::Engine.root.join('config', 'sidekiq_scheduler.yml')
  if engine_schedule_file.exist?
    begin
      engine_schedule = YAML.load(engine_schedule_file.read) || {}
      merged_schedule.merge!(engine_schedule)
      Rails.logger.info "Loaded Community Engine Sidekiq Scheduler from #{engine_schedule_file}"
    rescue StandardError => e
      Rails.logger.error "Failed to load engine Sidekiq Scheduler: #{e.message}"
    end
  end

  # Load host app's schedule (overrides engine schedule for same job names)
  host_schedule_file = Rails.root.join('config', 'sidekiq_scheduler.yml')
  if host_schedule_file.exist?
    begin
      host_schedule = YAML.load(host_schedule_file.read) || {}
      merged_schedule.merge!(host_schedule)
      Rails.logger.info "Loaded host app Sidekiq Scheduler from #{host_schedule_file}"
    rescue StandardError => e
      Rails.logger.error "Failed to load host app Sidekiq Scheduler: #{e.message}"
    end
  end

  # Set the merged schedule
  if merged_schedule.any?
    Sidekiq.schedule = merged_schedule
    Sidekiq::Scheduler.reload_schedule!
    Rails.logger.info "Loaded #{merged_schedule.keys.count} scheduled job(s): #{merged_schedule.keys.join(', ')}"
  else
    Rails.logger.warn 'No Sidekiq Scheduler jobs found in engine or host app'
  end
end
