# frozen_string_literal: true

# Load sidekiq-cron schedule from YAML on Sidekiq server boot.
if defined?(Sidekiq) && Sidekiq.server?
  schedule_file = Rails.root.join('config', 'sidekiq_cron.yml')

  if schedule_file.exist?
    begin
      schedule = YAML.safe_load(schedule_file.read) || {}
      Sidekiq::Cron::Job.load_from_hash(schedule)
      Rails.logger.info "Loaded sidekiq-cron schedule from #{schedule_file}"
    rescue StandardError => e
      Rails.logger.error "Failed to load sidekiq-cron schedule: #{e.message}"
    end
  end
end
