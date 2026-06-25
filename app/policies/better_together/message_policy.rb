# frozen_string_literal: true

module BetterTogether
  # Access control for conversation messages.
  class MessagePolicy < PlatformRecordPolicy
    def show?
      user.present? && participant?
    end

    def create?
      user.present? && participant?
    end

    def update?
      user.present? && sender?
    end
    alias edit? update?

    def destroy?
      user.present? && sender?
    end

    # Pundit scope for Message visibility within conversations.
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        return scope.none unless user.present? && agent

        conversations = BetterTogether::Conversation.joins(:participants)
                                                    .where(better_together_people: { id: agent.id })
        platform_scoped.joins(:conversation)
                       .where(conversation: { id: conversations })
      end
    end

    private

    def participant?
      conversation = record.try(:conversation)
      conversation.present? && conversation.participants.include?(agent)
    end

    def sender?
      record.sender == agent
    end
  end
end
