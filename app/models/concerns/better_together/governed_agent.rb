# frozen_string_literal: true

module BetterTogether
  # Shared identity helpers for people and robots participating in the
  # community action network. This is a lightweight foundation for future
  # actor-safe authorship and agreement participation work.
  module GovernedAgent
    extend ActiveSupport::Concern

    class_methods do
      def governed_agent_type
        name.demodulize.underscore
      end
    end

    def governed_agent?
      true
    end

    def governed_agent_type
      self.class.governed_agent_type
    end

    def governed_agent_identifier
      return identifier if respond_to?(:identifier) && identifier.present?

      id&.to_s
    end

    def governed_agent_display_name
      return name if respond_to?(:name) && name.present?

      governed_agent_identifier
    end

    def governed_agent_key
      [governed_agent_type, governed_agent_identifier].compact.join(':')
    end

    def governed_agent_label
      "#{governed_agent_display_name} (#{governed_agent_type})"
    end
  end
end

