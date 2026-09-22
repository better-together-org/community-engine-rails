# frozen_string_literal: true

module BetterTogether
  # Authorization for MessageRequest — only participants (sender/recipient) may access.
  class MessageRequestPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present? && feature_enabled?('message_requests')
    end

    def create?
      user.present? && agent.present? && feature_enabled?('message_requests')
    end

    def show?
      participant? && feature_enabled?('message_requests')
    end

    def accept?
      user.present? && agent == record.recipient && feature_enabled?('message_requests')
    end

    def decline?
      accept?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present? && agent.present?
        return scope.none unless feature_enabled?('message_requests')

        scope.where(sender: agent).or(scope.where(recipient: agent))
      end
    end

    private

    def participant?
      user.present? && agent.present? &&
        (agent == record.sender || agent == record.recipient)
    end
  end
end
