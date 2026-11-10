# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Making, listing, downloading and deleting saved billing reports, shown as the Reports list of the Billing tab in
    # the metrics dashboard. Same flow as the user account reports (a Turbo frame list, a job that builds the CSV, a
    # download), but every lookup is inside the current platform.
    class BillingReportsController < ApplicationController
      include PlatformContext

      before_action :authorize_index, only: %i[index]
      before_action :authorize_create, only: %i[new create]
      before_action :set_report, only: %i[download destroy]

      def index
        @billing_reports = reports.includes(:creator)
        if turbo_frame?
          return render partial: 'better_together/metrics/billing_reports/index', locals: { billing_reports: @billing_reports },
                        layout: false
        end

        render :index
      end

      def new
        @billing_report = BillingReport.new
      end

      def create
        BillingReport.create_and_generate!(creator: helpers.current_person, platform: metrics_platform, **report_params)
        redirect_to metrics_billing_reports_path, notice: t('flash.generic.created', resource: t('resources.report'))
      end

      def download # rubocop:disable Metrics/AbcSize
        authorize @billing_report, :download?, policy_class: BillingReportPolicy
        return redirect_to metrics_billing_reports_path, alert: t('resources.download_failed') unless @billing_report.report_file.attached?

        file = @billing_report.report_file
        TrackDownloadJob.perform_later(@billing_report, file.filename.to_s, file.content_type, file.byte_size, I18n.locale.to_s,
                                       metrics_platform.id, metrics_logged_in?)
        send_data file.download, filename: file.filename.to_s, type: file.content_type, disposition: 'attachment'
      end

      def destroy
        authorize @billing_report, :destroy?, policy_class: BillingReportPolicy
        @billing_report.destroy
        redirect_to metrics_billing_reports_path, notice: t('flash.generic.destroyed', resource: t('resources.report'))
      end

      private

      def authorize_index = authorize(%i[metrics billing_report], :index?, policy_class: BillingReportPolicy)

      def authorize_create = authorize(%i[metrics billing_report], :create?, policy_class: BillingReportPolicy)

      def turbo_frame? = request.headers['Turbo-Frame'].present?

      def reports = BillingReport.for_platform(metrics_platform)

      def set_report
        @billing_report = reports.find(params[:id])
      end

      def report_params
        permitted = params.fetch(:metrics_billing_report, {}).permit(:file_format, filters: %i[from_date to_date owner interval])
        filters = permitted.fetch(:filters, {})
        { from_date: filters[:from_date], to_date: filters[:to_date], owner: filters[:owner].to_s, interval: filters[:interval].to_s,
          file_format: permitted[:file_format].presence || 'csv' }
      end
    end
  end
end
