# frozen_string_literal: true

module BetterTogether
  # Test notifier for specs
  class TestNotifier < Noticed::Event
    # Optional: add any specific behavior for testing
    def self.build_for_test(data = {})
      new(data)
    end
  end
end
