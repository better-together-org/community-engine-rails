# frozen_string_literal: true

module BetterTogether
  class CalendarPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present? && record.creator == agent
    end

    def create?
      user.present?
    end

    class Scope < ApplicationPolicy::Scope
    end
  end
end
