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
      @report = build_report_from_query
      return render_invalid_reportable unless valid_reportable_request?

      authorize @report
    end

    def create
      @report = build_report
      return render_invalid_reportable unless valid_reportable_request?

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

    def build_report_from_query
      helpers.current_person.reports_made.new.tap do |report|
        assign_reportable(report, requested_reportable_type, requested_reportable_id)
      end
    end

    def build_report
      helpers.current_person.reports_made.new(report_params).tap do |report|
        assign_reportable(report, requested_reportable_type, requested_reportable_id)
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

    def resolved_reportable(reportable_type, reportable_id)
      klass = BetterTogether::SafeClassResolver.resolve!(
        reportable_type,
        allowed: BetterTogether::Report::ALLOWED_REPORTABLES,
        error_class: SecurityError
      )

      klass.find(reportable_id)
    rescue NameError, SecurityError, ActiveRecord::RecordNotFound
      nil
    end

    def valid_reportable_request?
      return true unless reportable_lookup_requested?

      @report.reportable.present?
    end

    def assign_reportable(report, reportable_type, reportable_id)
      return unless reportable_type.present?

      report.reportable = resolved_reportable(reportable_type, reportable_id)
    end

    def reportable_lookup_requested?
      requested_reportable_type.present? || requested_reportable_id.present?
    end

    def requested_reportable_type
      @requested_reportable_type ||= reportable_source_params[:reportable_type]
    end

    def requested_reportable_id
      @requested_reportable_id ||= reportable_source_params[:reportable_id]
    end

    def reportable_source_params
      @reportable_source_params ||= if params[:report].is_a?(ActionController::Parameters)
                                      params.require(:report).permit(:reportable_type, :reportable_id)
                                    else
                                      params.permit(:reportable_type, :reportable_id)
                                    end
    end

    def render_invalid_reportable
      skip_authorization
      head :not_found
    end
  end
end
