# frozen_string_literal: true

# Use this file with the 'whenever' gem to schedule the daily link checker report.
# Example: whenever --update-crontab

set :output, 'log/cron.log'

every 1.day, at: '2:00 am' do
  rake 'metrics:link_checker_daily'
end
