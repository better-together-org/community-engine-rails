# frozen_string_literal: true

module BetterTogether
  class ReportPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      user.present? && record.reporter == agent && record.reporter != record.reportable
    end
  end
end
