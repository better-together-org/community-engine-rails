# frozen_string_literal: true

module BetterTogether
  # Access control for a single occurrence's override (location/time/
  # description/cancellation). Deliberately delegates every host/creator
  # check to the parent Event via EventHostAuthorizable — an EventOccurrence
  # never carries its own EventHost data, so authorization here is always
  # "could this person manage the parent series," never a separate grant.
  class EventOccurrencePolicy < ApplicationPolicy
    include SelfServicePublishablePolicy
    include EventHostAuthorizable

    def event_for_authorization
      record.event
    end

    def show?
      Pundit.policy!(user, event_for_authorization).show?
    end

    def create?
      update?
    end

    def new?
      create?
    end

    def update?
      creator_or_platform_steward || event_host_member?
    end

    def edit?
      update?
    end

    def destroy?
      update?
    end

    # An occurrence's visibility is entirely inherited from its parent
    # Event's visibility — it has no privacy/status of its own. Overrides
    # ApplicationPolicy::Scope's default (which assumes the Privacy concern,
    # not present on EventOccurrence) rather than calling super.
    class Scope < ApplicationPolicy::Scope
      def resolve
        visible_event_ids = Pundit.policy_scope!(user, ::BetterTogether::Event).select(:id)
        scope.where(event_id: visible_event_ids)
      end
    end
  end
end
