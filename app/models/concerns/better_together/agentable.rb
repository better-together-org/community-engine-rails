# frozen_string_literal: true

module BetterTogether
  # Shared identity helpers for people and robots participating in the
  # community action network. This is a lightweight foundation for future
  # actor-safe authorship and agreement participation work.
  module Agentable
    extend ActiveSupport::Concern

    class_methods do
      def agent_type
        name.demodulize.underscore
      end
    end

    def agent?
      true
    end

    def agent_type
      self.class.agent_type
    end

    def agent_identifier
      return identifier if respond_to?(:identifier) && identifier.present?

      id&.to_s
    end

    def agent_display_name
      return name if respond_to?(:name) && name.present?

      agent_identifier
    end

    def agent_key
      [agent_type, agent_identifier].compact.join(':')
    end

    def agent_label
      "#{agent_display_name} (#{agent_type})"
    end

    def accepted_agreement?(identifier)
      BetterTogether::ChecksRequiredAgreements.accepted_agreement?(self, identifier:)
    end
  end
end
