# frozen_string_literal: true

# Load Sidekiq Scheduler schedule file when Sidekiq server starts.
if defined?(Sidekiq) && Sidekiq.server?
  schedule_file = Rails.root.join('config', 'sidekiq_scheduler.yml')

  if schedule_file.exist?
    begin
      schedule = YAML.safe_load(schedule_file.read) || {}
      Sidekiq.schedule = schedule
      Sidekiq::Scheduler.reload_schedule!
      Rails.logger.info "Loaded Sidekiq Scheduler from #{schedule_file}"
    rescue StandardError => e
      Rails.logger.error "Failed to load Sidekiq Scheduler: #{e.message}"
    end
  end
end
