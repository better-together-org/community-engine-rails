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
  config.before(:suite) { ActiveRecord::Migration.verbose = false }
end
