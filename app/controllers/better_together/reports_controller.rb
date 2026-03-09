# frozen_string_literal: true

module BetterTogether
  class ReportsController < ApplicationController # rubocop:todo Style/Documentation
    before_action :authenticate_user!
    before_action :set_report, only: :show
    after_action :verify_authorized

    def index
      authorize Report
      @reports = policy_scope(Report).includes(:safety_case, :reportable)
    end

    def show
      authorize @report
    end

    def new
      @report = helpers.current_person.reports_made.new(
        reportable_id: params[:reportable_id],
        reportable_type: params[:reportable_type]
      )
      authorize @report
    end

    def create
      @report = build_report
      authorize @report

      if @report.save
        redirect_to report_path(@report, locale: I18n.locale),
                    notice: t('better_together.reports.notices.created',
                              default: 'Report was successfully submitted.')
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def build_report
      helpers.current_person.reports_made.new(report_params).tap do |report|
        report.reportable = resolved_reportable if report_params[:reportable_type].present?
      end
    end

    def set_report
      @report = policy_scope(Report).find(params[:id])
    end

    def report_params
      params.require(:report).permit(
        :reportable_id,
        :reportable_type,
        :reason,
        :category,
        :harm_level,
        :requested_outcome,
        :private_details,
        :consent_to_contact,
        :consent_to_restorative_process,
        :retaliation_risk
      )
    end

    def resolved_reportable
      klass = BetterTogether::SafeClassResolver.resolve!(
        report_params[:reportable_type],
        allowed: BetterTogether::Report::ALLOWED_REPORTABLES,
        error_class: SecurityError
      )

      klass.find(report_params[:reportable_id])
    rescue NameError, SecurityError, ActiveRecord::RecordNotFound
      nil
    end
  end
end
