# frozen_string_literal: true

module BetterTogether
  class HubPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      permitted_to?('manage_platform')
    end
  end
end
