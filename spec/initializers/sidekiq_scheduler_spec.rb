# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Sidekiq Scheduler Configuration' do
  let(:engine_schedule_path) { BetterTogether::Engine.root.join('config', 'sidekiq_scheduler.yml') }
  let(:host_schedule_path) do
    # Use unique path per parallel worker to avoid file conflicts
    test_suffix = ENV['TEST_ENV_NUMBER'].to_s
    Rails.root.join('config', "sidekiq_scheduler#{test_suffix}.yml")
  end
  let(:initializer_path) { BetterTogether::Engine.root.join('config/initializers/sidekiq_scheduler.rb') }

  describe 'engine schedule file' do
    it 'exists in the engine' do
      expect(engine_schedule_path).to exist
    end

    it 'contains valid YAML' do
      expect { YAML.load(engine_schedule_path.read) }.not_to raise_error
    end

    it 'defines scheduled jobs' do
      schedule = YAML.load(engine_schedule_path.read)

      expect(schedule).to be_a(Hash)
      expect(schedule.keys).to include(
        'better_together:metrics:link_checker_weekly',
        'better_together:event_reminder_scan_hourly'
      )
    end

    describe 'link checker job configuration' do
      let(:schedule) { YAML.load(engine_schedule_path.read) }
      let(:job) { schedule['better_together:metrics:link_checker_weekly'] }

      it 'has correct cron schedule' do
        expect(job['cron']).to eq('0 2 * * 1')
      end

      it 'has correct job class' do
        expect(job['class']).to eq('BetterTogether::Metrics::LinkCheckerReportSchedulerJob')
      end

      it 'uses metrics queue' do
        expect(job['queue']).to eq('metrics')
      end

      it 'has a description' do
        expect(job['description']).to be_present
      end
    end

    describe 'event reminder job configuration' do
      let(:schedule) { YAML.load(engine_schedule_path.read) }
      let(:job) { schedule['better_together:event_reminder_scan_hourly'] }

      it 'has correct cron schedule' do
        expect(job['cron']).to eq('0 * * * *')
      end

      it 'has correct job class' do
        expect(job['class']).to eq('BetterTogether::EventReminderScanJob')
      end

      it 'uses notifications queue' do
        expect(job['queue']).to eq('notifications')
      end

      it 'has a description' do
        expect(job['description']).to be_present
      end
    end
  end

  describe 'initializer' do
    it 'exists' do
      expect(initializer_path).to exist
    end

    it 'contains valid Ruby code' do
      expect { load initializer_path }.not_to raise_error(SyntaxError)
    end

    describe 'schedule loading logic' do
      let(:initializer_content) { File.read(initializer_path) }

      it 'references the engine schedule path' do
        expect(initializer_content).to include("BetterTogether::Engine.root.join('config', 'sidekiq_scheduler.yml')")
      end

      it 'references the host app schedule path' do
        expect(initializer_content).to include("Rails.root.join('config', 'sidekiq_scheduler.yml')")
      end

      it 'merges schedules' do
        expect(initializer_content).to include('merge!')
      end

      it 'checks for Sidekiq server mode' do
        expect(initializer_content).to include('Sidekiq.server?')
      end

      it 'includes logging for debugging' do
        expect(initializer_content).to include('Rails.logger.info')
      end

      it 'documents override capability' do
        expect(initializer_content).to include('enabled: false')
      end
    end
  end

  describe 'host app override capability' do
    let(:host_schedule_path) { Rails.root.join('tmp', 'spec', "sidekiq_scheduler_#{SecureRandom.hex(6)}.yml") }

    before do
      # Ensure clean state before each test
      FileUtils.rm_f(host_schedule_path) if host_schedule_path.exist?
      # Ensure the config directory exists
      FileUtils.mkdir_p(host_schedule_path.dirname)
    end

    after do
      # Clean up after each test
      FileUtils.rm_f(host_schedule_path) if host_schedule_path.exist?
    end

    it 'can disable engine jobs via host app config' do
      host_schedule = {
        'better_together:metrics:link_checker_weekly' => {
          'enabled' => false
        }
      }
      File.write(host_schedule_path, host_schedule.to_yaml)

      engine_schedule = YAML.safe_load_file(engine_schedule_path)
      host_override = YAML.safe_load_file(host_schedule_path)
      merged = engine_schedule.merge(host_override)

      expect(merged['better_together:metrics:link_checker_weekly']['enabled']).to be false
    end

    it 'can modify engine job schedules via host app config' do
      host_schedule = {
        'better_together:event_reminder_scan_hourly' => {
          'cron' => '0 */2 * * *', # Every 2 hours instead of hourly
          'class' => 'BetterTogether::EventReminderScanJob',
          'queue' => 'low_priority'
        }
      }
      File.write(host_schedule_path, host_schedule.to_yaml)

      engine_schedule = YAML.safe_load_file(engine_schedule_path)
      host_override = YAML.safe_load_file(host_schedule_path)
      merged = engine_schedule.merge(host_override)

      expect(merged['better_together:event_reminder_scan_hourly']['cron']).to eq('0 */2 * * *')
      expect(merged['better_together:event_reminder_scan_hourly']['queue']).to eq('low_priority')
    end

    it 'can add new jobs via host app config' do
      host_schedule = {
        'app_specific:custom_job' => {
          'cron' => '0 3 * * *',
          'class' => 'CustomJob',
          'queue' => 'default'
        }
      }
      File.write(host_schedule_path, host_schedule.to_yaml)

      engine_schedule = YAML.safe_load_file(engine_schedule_path)
      host_override = YAML.safe_load_file(host_schedule_path)
      merged = engine_schedule.merge(host_override)

      expect(merged.keys).to include(
        'better_together:metrics:link_checker_weekly',
        'better_together:event_reminder_scan_hourly',
        'app_specific:custom_job'
      )
    end
  end

  describe 'schedule readiness for execution', :skip_host_setup do
    let(:engine_schedule) { YAML.load(BetterTogether::Engine.root.join('config', 'sidekiq_scheduler.yml').read) }

    context 'job configuration completeness' do
      it 'all jobs have required fields for execution' do
        engine_schedule.each do |job_name, job_config|
          expect(job_config).to include('cron'), "Job #{job_name} missing cron schedule"
          expect(job_config).to include('class'), "Job #{job_name} missing class definition"
          expect(job_config).to include('queue'), "Job #{job_name} missing queue definition"
        end
      end

      it 'validates cron expression format for link checker' do
        job = engine_schedule['better_together:metrics:link_checker_weekly']
        cron = job['cron']

        # Weekly cron format validation (5 fields: minute hour day month weekday)
        expect(cron).to match(/^\d+\s+\d+\s+\*\s+\*\s+\d+$/)
        expect(cron.split.size).to eq(5)
      end

      it 'validates cron expression format for event reminder' do
        job = engine_schedule['better_together:event_reminder_scan_hourly']
        cron = job['cron']

        # Hourly cron format (every hour)
        expect(cron).to match(/^0\s+\*\s+\*\s+\*\s+\*$/)
        expect(cron.split.size).to eq(5)
      end

      it 'ensures job classes follow naming conventions' do
        engine_schedule.each_value do |job_config|
          class_name = job_config['class']
          expect(class_name).to start_with('BetterTogether::')
          expect(class_name).to end_with('Job')
        end
      end

      it 'ensures queue names are valid' do
        valid_queues = %w[default metrics notifications events maintenance]
        engine_schedule.each do |job_name, job_config|
          expect(valid_queues).to include(job_config['queue']),
                                  "Job #{job_name} uses invalid queue: #{job_config['queue']}"
        end
      end
    end

    context 'schedule timing validation' do
      it 'link checker runs at off-peak hours (2 AM UTC on Mondays)' do
        job = engine_schedule['better_together:metrics:link_checker_weekly']
        cron_parts = job['cron'].split

        hour = cron_parts[1]
        weekday = cron_parts[4]
        expect(hour).to eq('2'), 'Link checker should run at 2 AM UTC (off-peak)'
        expect(weekday).to eq('1'), 'Link checker should run on Mondays'
      end

      it 'event reminder runs every hour on the hour' do
        job = engine_schedule['better_together:event_reminder_scan_hourly']
        cron_parts = job['cron'].split

        minute = cron_parts[0]
        hour = cron_parts[1]
        expect(minute).to eq('0'), 'Should run at minute 0'
        expect(hour).to eq('*'), 'Should run every hour'
      end
    end

    context 'job class existence' do
      it 'link checker job class is defined' do
        expect(defined?(BetterTogether::Metrics::LinkCheckerReportSchedulerJob)).to be_truthy
      end

      it 'event reminder job class is defined' do
        expect(defined?(BetterTogether::EventReminderScanJob)).to be_truthy
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
