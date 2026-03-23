# frozen_string_literal: true

# Fixes PG::ObjectInUse race condition in parallel_rspec.
#
# parallel_rspec forks N workers that each call purge_current on their assigned
# test database. Worker 1 handles rails_test. The parent Rake process holds an
# open connection to rails_test (established when the Rails environment loads),
# which causes DROP DATABASE to fail with PG::ObjectInUse.
#
# Fix: before the parent forks workers, terminate all connections to test
# databases via pg_stat_activity and close active AR sockets from the parent
# process so the fork inherits no live database connections.
#
# The connection pool specification (host, port, credentials) is preserved so
# subsequent tasks (db:parallel:load_schema) can still resolve configuration.

return unless defined?(Rake)

namespace :db do
  namespace :parallel do
    task :disconnect_before_purge, [:env] => %i[environment load_config] do
      next unless defined?(ActiveRecord)

      configs = if ActiveRecord::Base.configurations.respond_to?(:configs_for)
                  ActiveRecord::Base.configurations.configs_for(env_name: 'test')
                else
                  Array(ActiveRecord::Base.configurations['test'])
                end

      configs.each do |config|
        db_cfg = config.respond_to?(:configuration_hash) ? config.configuration_hash : config.to_h.symbolize_keys
        base_db = db_cfg[:database] || db_cfg['database']
        next unless base_db.present?

        target_dbs = [base_db] + (2..4).map { |n| "#{base_db}#{n}" }
        admin_cfg  = db_cfg.symbolize_keys.merge(database: 'postgres')

        begin
          # Switch to the postgres admin DB to terminate connections.
          ActiveRecord::Base.establish_connection(admin_cfg)
          target_dbs.each do |target_db|
            ActiveRecord::Base.connection.execute(
              'SELECT pg_terminate_backend(pid) FROM pg_stat_activity ' \
              "WHERE datname = '#{target_db}' AND pid <> pg_backend_pid()"
            )
          rescue StandardError => e
            warn "[parallel_db_fix] Could not terminate connections to #{target_db}: #{e.message}"
          end
        ensure
          # Restore the test DB connection spec so subsequent Rake tasks
          # (e.g. db:parallel:load_schema) do not receive ConnectionNotDefined.
          ActiveRecord::Base.establish_connection(db_cfg.symbolize_keys)
        end
      end

      # Close all active sockets in the parent process so forked workers do
      # not inherit open connections. The pool spec is preserved above.
      ActiveRecord::Base.connection_handler.clear_all_connections!
    end
  end
end

# Ensure db:parallel:purge exists (parallel_rspec may define it after this file loads).
unless Rake::Task.task_defined?('db:parallel:purge')
  namespace :db do
    namespace :parallel do
      task :purge
    end
  end
end

Rake::Task['db:parallel:purge'].enhance(['db:parallel:disconnect_before_purge'])
