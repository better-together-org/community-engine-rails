# frozen_string_literal: true

module BetterTogether
  class CommunityPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && permitted_to?('list_community')
    end

    def show?
      (record.privacy_public? || user.present?) && permitted_to?('read_community')
    end

    def create?
      user.present? && permitted_to?('create_community')
    end

    def new?
      create?
    end

    def update?
      user.present? && !record.protected? && permitted_to?('update_community')
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected? && !record.host?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.order(:host, :identifier)
      end
    end
  end
end
