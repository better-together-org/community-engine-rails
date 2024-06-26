# frozen_string_literal: true

# app/policies/better_together/role_policy.rb

module BetterTogether
  class PagePolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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
      user.present? && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        scope.order(:slug)
      end
    end
  end
end
