# frozen_string_literal: true

# Keeps CI logs readable: silences migration chatter and collapses repeated
# gem warnings. Deprecation warnings are intentionally left untouched.
module QuietRepeatedWarnings
  REPEAT_PATTERN = /\APerformance issue detected:/
  SEEN = Set.new
  LOCK = Mutex.new

  def warn(message, **)
    return if message.to_s.match?(REPEAT_PATTERN) && LOCK.synchronize { !SEEN.add?(message.to_s) }

    super
  end
end
Warning.singleton_class.prepend(QuietRepeatedWarnings)

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Migration.verbose = false
    # The builder reports progress with puts on every seed/reset (about 100 lines per shard).
    BetterTogether::NavigationBuilder.singleton_class.prepend(Module.new { def puts(*) = nil })
  end
end

# Specs that assert on migration output wrap just that block, so setup and
# teardown stay quiet.
module MigrationOutputHelper
  def with_migration_output
    previous = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = true
    yield
  ensure
    ActiveRecord::Migration.verbose = previous
  end
end

RSpec.configure { |config| config.include MigrationOutputHelper }
