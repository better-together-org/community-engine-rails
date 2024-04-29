# frozen_string_literal: true

module BetterTogether
  class PersonPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      user.present?
    end

    def create?
      user.present?
    end

    def new?
      create?
    end

    def update?
      user.present? && me?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && (me? || has_permission?('delete_person'))
    end

    def me?
      record === user.person # rubocop:todo Style/CaseEquality
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.with_translations
      end
    end
  end
end
