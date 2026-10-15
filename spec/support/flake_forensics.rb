# frozen_string_literal: true

# When an example fails with the signature of leaked database state ("already been taken", a unique or
# foreign-key violation, a broken rollback), record what that worker ran just before it and which of the
# suspect rows are COMMITTED (visible to a second connection) versus only inside the example's transaction.
# This makes a CI-only flake traceable from the job log instead of from guesses. It changes no behaviour.
module FlakeForensics
  LEAK_SIGNATURE = /already been taken|PG::UniqueViolation|PG::ForeignKeyViolation|cmd_tuples/
  RECENT_LIMIT = 8
  RECENT = [] # rubocop:disable Style/MutableConstant

  class << self
    def remember(example)
      kind = [example.metadata[:type] || '-', ('js' if example.metadata[:js])].compact.join(' ')
      RECENT << "#{example.metadata[:location]} [#{kind}]"
      RECENT.shift while RECENT.size > RECENT_LIMIT
    end

    def report(example)
      exception = example.exception
      return unless leak?(exception)

      lines = report_lines(example, exception)
      lines.each { |line| warn line }
      Rails.logger.error(lines.join("\n"))
    rescue StandardError => e
      warn "[FLAKE-FORENSICS] could not report: #{e.class}: #{e.message}"
    end

    private

    def leak?(exception)
      exception && exception.message.to_s.match?(LEAK_SIGNATURE)
    end

    def report_lines(example, exception)
      [
        "[FLAKE-FORENSICS] #{example.metadata[:location]} #{exception.class}: #{exception.message.to_s.lines.first&.strip}",
        "  process pid=#{Process.pid} TEST_ENV_NUMBER=#{ENV['TEST_ENV_NUMBER'].inspect} #{connection_facts}",
        "  committed rows (second connection): #{committed_counts}",
        "  previous examples in this process: #{RECENT.join(' | ')}"
      ]
    end

    def connection_facts
      connection = ActiveRecord::Base.connection
      "db=#{connection.current_database} backend=#{connection.select_value('SELECT pg_backend_pid()')} " \
        "open_transactions=#{connection.open_transactions}"
    end

    # Committed state only: a separate connection cannot see this example's uncommitted rows.
    def committed_counts
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      conn = PG.connect(host: config[:host], port: config[:port], user: config[:username], password: config[:password],
                        dbname: config[:database])
      queries = {
        manager_users: "SELECT count(*) FROM better_together_users WHERE email = 'manager@example.test'",
        manager_people: "SELECT count(*) FROM better_together_people WHERE identifier = 'manager-example-test'",
        agreement_participants: 'SELECT count(*) FROM better_together_agreement_participants',
        publishing_agreements: "SELECT count(*) FROM better_together_agreements WHERE identifier = 'content_publishing_agreement'"
      }
      queries.map { |name, sql| "#{name}=#{conn.exec(sql).getvalue(0, 0)}" }.join(' ')
    ensure
      conn&.close
    end
  end
end

RSpec.configure do |config|
  # prepend_after runs before the cleaner's after hook, so the rows are still there to inspect.
  config.prepend_after { |example| FlakeForensics.report(example) }
  config.after { |example| FlakeForensics.remember(example) }
end
