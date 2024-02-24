# frozen_string_literal: true

# app/policies/better_together/navigation_item_policy.rb

module BetterTogether
  class PagePolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      (record.published? && record.privacy_public?) || user.present?
    end

    def create?
      user.present?
    end

    def new?
      create?
    end

    def update?
      user.present?
    end

    def edit?
      update?
    end

    def destroy?
      user.present?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.all
      end
    end
  end
end
