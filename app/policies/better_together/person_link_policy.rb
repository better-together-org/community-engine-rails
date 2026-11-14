# frozen_string_literal: true

module BetterTogether
  # Access control for person-to-person platform links.
  class PersonLinkPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present?
    end

    def show?
      user.present? && participant?
    end

    def revoke?
      user.present? && source_participant?
    end

    # Pundit scope for PersonLink visibility.
    # Scoped to the current platform's connections so agents cannot see links from
    # unrelated platform federations even if they are a participant there too.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        person_scope = scope.where(source_person_id: agent.id)
                            .or(scope.where(target_person_id: agent.id))

        platform = Current.platform || Current.host_platform
        return person_scope unless platform

        person_scope.for_platform(platform)
      end
    end

    private

    def participant?
      record.source_person_id == agent.id || record.target_person_id == agent.id
    end

    def source_participant?
      record.source_person_id == agent.id
    end
  end
end
