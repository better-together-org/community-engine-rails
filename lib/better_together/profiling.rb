# frozen_string_literal: true

module BetterTogether
  # Central toggle for optional profiling libraries that should stay disabled
  # in normal production traffic unless an operator explicitly enables them.
  module Profiling
    module_function

    def enabled?
      env_value = ENV.fetch('BETTER_TOGETHER_ENABLE_PROFILING', nil)
      return truthy?(env_value) unless env_value.nil?

      ENV.fetch('RAILS_ENV', nil) == 'development'
    end

    def truthy?(value)
      %w[1 true yes on].include?(value.to_s.strip.downcase)
    end
  end
end
