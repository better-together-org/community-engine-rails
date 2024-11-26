# frozen_string_literal: true

module BetterTogether
  class PersonPolicy < ApplicationPolicy
    def index?
      user.present? && permitted_to?('list_person')
    end

    def show?
      user.present? && (me? || permitted_to?('read_person'))
    end

    def create?
      user.present? && permitted_to?('create_person')
    end

    def new?
      create?
    end

    def update?
      user.present? && (me? || permitted_to?('update_person'))
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && permitted_to?('delete_person')
    end

    def me?
      record === user.person # rubocop:todo Style/CaseEquality
    end

    class Scope < Scope
      def resolve
        scope.with_translations
      end
    end
  end
end
