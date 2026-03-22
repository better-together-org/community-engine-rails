# frozen_string_literal: true

module BetterTogether
  # RBAC for Event Categories
  class EventCategoryPolicy < CategoryPolicy
    class Scope < CategoryPolicy::Scope
    end
  end
end
