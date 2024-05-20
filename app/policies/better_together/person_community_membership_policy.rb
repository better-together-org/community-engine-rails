# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      user.present?
    end

    def destroy?
      user.present? && !me?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end

    protected

    def me?
      record.member == agent
    end
  end
end
