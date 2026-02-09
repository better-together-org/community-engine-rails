# frozen_string_literal: true

module DatabaseVisibilityHelpers
  # Ensures records created in test thread are visible to application server thread
  # Critical for :js feature specs using DatabaseCleaner with :deletion strategy
  def ensure_record_visible(record)
    return unless record

    # Force write to database if record is new or has changes
    record.save! if record.new_record? || record.changed?

    # Clear ActiveRecord query cache across all connections
    ActiveRecord::Base.connection_pool.connections.each(&:clear_query_cache)

    # Verify record is findable via fresh query across different connection
    # Use a new connection from the pool to simulate what app server will see
    record.class.connection_pool.with_connection do |conn|
      # Clear cache on this connection too
      conn.clear_query_cache
      # Query using this fresh connection
      record.class.find(record.id)
    end

    # Small sleep to ensure database has flushed writes to disk
    # Critical for PostgreSQL with multiple connections
    sleep 0.05

    record
  end

  # Ensures an array of records are visible
  def ensure_records_visible(records)
    Array(records).each { |record| ensure_record_visible(record) }
    # Additional small sleep after batch to ensure all are committed
    sleep 0.05
    records
  end

  # Wait for a record to be findable in database (useful after async operations)
  def wait_for_record(klass, id, timeout: 5)
    Timeout.timeout(timeout) do
      loop do
        # Clear query cache on each attempt
        ActiveRecord::Base.connection_pool.connections.each(&:clear_query_cache)

        record = klass.find(id)
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
