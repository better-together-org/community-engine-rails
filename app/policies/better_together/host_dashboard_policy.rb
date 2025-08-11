# frozen_string_literal: true

# app/policies/better_together/host_dashboard_policy.rb

module BetterTogether
  class HostDashboardPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && user.permitted_to?('manage_platform')
    end
  end
end
