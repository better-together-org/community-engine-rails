# frozen_string_literal: true

module BetterTogether
  class CategoryPolicy < ApplicationPolicy
    def index?
      permitted_to?('manage_platform')
    end

    def create?
      permitted_to?('manage_platform')
    end

    def update?
      permitted_to?('manage_platform')
    end

    def show?
      permitted_to?('manage_platform')
    end

    class Scope < ApplicationPolicy::Scope
    end
  end
end
