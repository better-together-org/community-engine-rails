# app/policies/better_together/navigation_item_policy.rb

module BetterTogether
  class NavigationItemPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      user.present?
    end

    def new?
      create?
    end

    def update?
      user.present?
    end

    def edit?
      update?
    end

    def destroy?
      user.present?
    end
  end
end
