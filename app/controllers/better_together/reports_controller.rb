# frozen_string_literal: true

module BetterTogether
  class ReportsController < ApplicationController # rubocop:todo Style/Documentation
    after_action :verify_authorized

    def create
      @report = current_person.reports_made.new(report_params)
      authorize @report

      if @report.save
        redirect_back fallback_location: root_path, notice: 'Report was successfully submitted.'
      else
        redirect_back fallback_location: root_path, alert: @report.errors.full_messages.to_sentence
      end
    end

    private

    def current_person
      current_user.person
    end

    def report_params
      params.require(:report).permit(:reportable_id, :reportable_type, :reason)
    end
  end
end
