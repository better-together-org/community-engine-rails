# frozen_string_literal: true

module BetterTogether
  class UserPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      user.present?
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      false
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
        scope.all
      end
    end
  end
end
