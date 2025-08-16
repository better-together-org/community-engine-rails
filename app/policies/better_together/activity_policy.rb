# frozen_string_literal: true

module BetterTogether
  # Access control fro PublicActivity::Activity records
  class ActivityPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      permitted_to?('manage_platform')
    end

    # Filter and sort public activity results
    class Scope < ApplicationPolicy::Scope
      def resolve
        results = scope.order(updated_at: :desc)

        query = table[:privacy].eq('public')

        results.where(query).where.not(trackable: nil)
      end

      def table
        scope.arel_table
      end
    end
  end
end
