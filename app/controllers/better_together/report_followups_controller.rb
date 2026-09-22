# frozen_string_literal: true

module BetterTogether
  # Allows reporters to add authenticated follow-up evidence to an existing report.
  class ReportFollowupsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_report
    after_action :verify_authorized

    def create
      authorize @report, :add_followup?

      @report_followup = @report.safety_case.notes.new(report_followup_params)
      @report_followup.author = current_user.person
      @report_followup.visibility = 'participant_visible'

      return redirect_to_report if @report_followup.save

      prepare_report_show_state
      render 'better_together/reports/show', status: :unprocessable_entity
    end

    private

    def set_report
      @report = policy_scope(Report).find(params[:report_id])
    end

    def redirect_to_report
      redirect_to report_path(@report, locale: I18n.locale),
                  notice: t(
                    'better_together.reports.notices.followup_created',
                    default: 'Your follow-up was added to the report.'
                  )
    end

    def prepare_report_show_state
      @participant_visible_notes = @report.safety_case.notes.participant_visible.chronological
    end

    def report_followup_params
      params.require(:report_followup).permit(:body)
    end
  end
end
