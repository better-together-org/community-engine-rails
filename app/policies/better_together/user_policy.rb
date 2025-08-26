# frozen_string_literal: true

module BetterTogether
  class UserPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      permitted_to?('manage_platform')
    end

    def show?
      user.present? && (record == user || permitted_to?('manage_platform'))
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      permitted_to?('manage_platform')
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    def me?
      record === user # rubocop:todo Style/CaseEquality
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.where(id: user.id) unless permitted_to?('manage_platform')

        scope.order(created_at: :desc)
      end
    end
  end
end
