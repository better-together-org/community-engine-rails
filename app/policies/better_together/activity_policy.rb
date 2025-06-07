# frozen_string_literal: true

module BetterTogether
  # Access control fro PublicActivity::Activity records
  class ActivityPolicy < ApplicationPolicy
    def index?
      permitted_to?('manage_platform')
    end

    def show?
      permitted_to?('manage_platform')
    end

    # Filter and sort public activity results
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.order(updated_at: :desc)
      end
    end
  end
end
