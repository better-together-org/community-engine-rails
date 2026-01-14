# frozen_string_literal: true

module BetterTogether
  # Test notifier for specs
  class TestNotifier < Noticed::Event
    # Optional: add any specific behavior for testing
    def self.build_for_test(data = {})
      new(data)
    end

    def title
      params[:test_message] || 'Test Notification'
    end

    def url
      params[:action_url] || '#'
    end
  end
end
