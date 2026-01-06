# frozen_string_literal: true

module BetterTogether
  # Policy for PersonPlatformIntegration authorization
  class PersonPlatformIntegrationPolicy < ApplicationPolicy
    # Users can view their own integrations
    def index?
      user.present?
    end

    # Users can view their own integrations
    def show?
      user.present? && record.user_id == user.id
    end

    # Users can create their own integrations
    def new?
      user.present?
    end

    # Users can create their own integrations
    def create?
      user.present?
    end

    # Users can edit their own integrations
    def edit?
      user.present? && record.user_id == user.id
    end

    # Users can update their own integrations
    def update?
      user.present? && record.user_id == user.id
    end

    # Users can destroy their own integrations
    def destroy?
      user.present? && record.user_id == user.id
    end

    # Scope for index action - users can only see their own integrations
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(user_id: user.id)
      end
    end
  end
end
