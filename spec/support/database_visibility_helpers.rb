# frozen_string_literal: true

module DatabaseVisibilityHelpers
  # Ensures records created in test thread are visible to application server thread
  # Critical for :js feature specs using DatabaseCleaner with :deletion strategy
  def ensure_record_visible(record)
    return unless record

    # Force write to database if record is new or has changes
    record.save! if record.new_record? || record.changed?

    # Clear any ActiveRecord query cache
    ActiveRecord::Base.connection.clear_query_cache

    # Verify record is findable via fresh query
    record.class.find(record.id)

    record
  end

  # Ensures an array of records are visible
  def ensure_records_visible(records)
    Array(records).each { |record| ensure_record_visible(record) }
    records
  end

  # Wait for a record to be findable in database (useful after async operations)
  def wait_for_record(klass, id, timeout: 5)
    Timeout.timeout(timeout) do
      loop do
        record = klass.find(id)
        ActiveRecord::Base.connection.clear_query_cache
        return record
      rescue ActiveRecord::RecordNotFound
        sleep 0.1
      end
    end
  rescue Timeout::Error
    raise "Timeout waiting for #{klass.name} with id #{id} to be findable"
  end
end

RSpec.configure do |config|
  config.include DatabaseVisibilityHelpers, type: :feature
end
