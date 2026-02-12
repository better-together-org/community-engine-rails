# frozen_string_literal: true

module DatabaseVisibilityHelpers
  # Ensures records created in test thread are visible to application server thread
  # Critical for :js feature specs using DatabaseCleaner with :deletion strategy
  def ensure_record_visible(record)
    return unless record

    # Force write to database if record is new or has changes
    record.save! if record.new_record? || record.changed?

    # Aggressively clear all connection caches and force a connection pool reset
    # This ensures fresh connections that will see the committed data
    clear_all_connection_caches!

    # Verify record is findable via multiple fresh queries
    # This simulates what app server will see from different connection pool checkouts
    3.times do
      record.class.connection_pool.with_connection do |conn|
        conn.clear_query_cache
        record.class.find(record.id)
      end
    end

    # Longer sleep to ensure PostgreSQL visibility across all connections
    # Critical for AJAX requests that fire immediately on page load
    sleep 0.3

    record
  end

  # Clear all connection caches aggressively
  def clear_all_connection_caches!
    # Clear query cache on all connections in the pool
    ActiveRecord::Base.connection_pool.connections.each do |conn|
      conn.clear_query_cache
    rescue StandardError
      nil
    end

    # Force the pool to disconnect idle connections
    # This ensures next checkout gets a truly fresh connection
    begin
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.connection_pool.clear_reloadable_connections!
    rescue StandardError => e
      # Don't fail if pool operations fail
      Rails.logger.debug "Connection pool clear failed: #{e.message}"
    end
  end

  # Ensures an array of records are visible
  def ensure_records_visible(records)
    Array(records).each { |record| ensure_record_visible(record) }
    # Additional aggressive cache clear after batch
    clear_all_connection_caches!
    # Longer sleep after batch to ensure all are committed
    sleep 0.3
    records
  end

  # Wait for a record to be findable in database (useful after async background job operations)
  #
  # WARNING: Do NOT use this for records created by Capybara/feature spec server actions.
  # When the Rails server creates a record and redirects to it, the redirect itself confirms
  # the record was committed to the database. Trying to verify it from the test thread can
  # cause timeout issues due to connection pooling and transaction isolation.
  #
  # PROPER USE CASE: Waiting for records created by background jobs (Sidekiq) that run
  # asynchronously and may not be immediately visible in the database.
  #
  # INCORRECT USE: Verifying records created by form submissions in feature specs.
  # Solution: Just verify the redirect/success feedback; subsequent queries will see the record.
  def wait_for_record(klass, id, timeout: 5)
    Timeout.timeout(timeout) do
      loop do
        # Clear all connection caches on each attempt
        clear_all_connection_caches!

        record = klass.find(id)
        return record
      rescue ActiveRecord::RecordNotFound
        sleep 0.15
      end
    end
  rescue Timeout::Error
    raise "Timeout waiting for #{klass.name} with id #{id} to be findable"
  end
end

RSpec.configure do |config|
  config.include DatabaseVisibilityHelpers, type: :feature
end
