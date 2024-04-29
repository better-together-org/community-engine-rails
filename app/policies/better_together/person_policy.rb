# frozen_string_literal: true

module BetterTogether
  class PersonPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && has_permission?('list_person')
    end

    def show?
      user.present? && has_permission?('read_person')
    end

    def create?
      user.present? && has_permission?('create_person')
    end

    def new?
      create?
    end

    def update?
      user.present? && (me? || has_permission?('update_person'))
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
