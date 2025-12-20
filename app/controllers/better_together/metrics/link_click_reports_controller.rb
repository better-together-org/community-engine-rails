# frozen_string_literal: true

module BetterTogether
  module Metrics
    # rubocop:todo Layout/LineLength
    # Manage LinkClickReport records tracking instances of reports run against the BetterTogether::Metrics::LinkClick records
    # rubocop:enable Layout/LineLength
    class LinkClickReportsController < ApplicationController
      before_action :set_link_click_report, only: [:download]

      # GET /metrics/link_click_reports
      def index
        authorize %i[metrics link_click_report], :index?,
                  policy_class: BetterTogether::Metrics::LinkClickReportPolicy
        @link_click_reports = BetterTogether::Metrics::LinkClickReport.order(created_at: :desc)
        if request.headers['Turbo-Frame'].present?
          render partial: 'better_together/metrics/link_click_reports/index',
                 locals: { link_click_reports: @link_click_reports }, layout: false
        else
          render :index
        end
      end

      # GET /metrics/link_click_reports/new
      def new
        authorize %i[metrics link_click_report], :create?,
                  policy_class: BetterTogether::Metrics::LinkClickReportPolicy
        @link_click_report = BetterTogether::Metrics::LinkClickReport.new
        # For LinkClick reports, you might want to let users filter by internal or external clicks.
        # For example, providing a selection list for internal (true) or external (false) clicks.
        @internal_options = [true, false]
      end

      # POST /metrics/link_click_reports
      def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        authorize %i[metrics link_click_report], :create?,
                  policy_class: BetterTogether::Metrics::LinkClickReportPolicy

        opts = {
          from_date: link_click_report_params.dig(:filters, :from_date),
          to_date: link_click_report_params.dig(:filters, :to_date),
          filter_internal: link_click_report_params.dig(:filters, :filter_internal),
          sort_by_total_clicks: link_click_report_params[:sort_by_total_clicks],
          file_format: link_click_report_params[:file_format]
        }

        @link_click_report = BetterTogether::Metrics::LinkClickReport.create_and_generate!(**opts)

        respond_to do |format| # rubocop:todo Metrics/BlockLength
          if @link_click_report.persisted?
            flash[:notice] = t('flash.generic.created', resource: t('resources.report'))
            format.html { redirect_to metrics_link_click_reports_path, notice: flash[:notice] }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.prepend('link_click_reports_table_body',
                                     partial: 'better_together/metrics/link_click_reports/link_click_report',
                                     locals: { link_click_report: @link_click_report }),
                turbo_stream.replace('flash_messages',
                                     partial: 'layouts/better_together/flash_messages',
                                     locals: { flash: flash }),
                turbo_stream.replace('new_report', '<turbo-frame id="new_report"></turbo-frame>')
              ]
            end
          else
            flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.report'))
            format.html { render :new, status: :unprocessable_content }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.update('form_errors',
                                    partial: 'layouts/errors',
                                    locals: { object: @link_click_report }),
                turbo_stream.replace('flash_messages',
                                     partial: 'layouts/better_together/flash_messages',
                                     locals: { flash: flash })
              ]
            end
          end
        end
      end

      # GET /metrics/link_click_reports/:id/download
      # rubocop:todo Metrics/MethodLength
      def download # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        authorize [:metrics, @link_click_report], :download?

        report = @link_click_report
        if report.report_file.attached?
          # Log the download via a background job.
          BetterTogether::Metrics::TrackDownloadJob.perform_later(
            report, # Fully namespaced model
            report.report_file.filename.to_s,         # Filename
            report.report_file.content_type,          # Content type
            report.report_file.byte_size,             # File size
            I18n.locale.to_s                          # Locale
          )

          send_data report.report_file.download,
                    filename: report.report_file.filename.to_s,
                    type: report.report_file.content_type,
                    disposition: 'attachment'
        else
          redirect_to metrics_link_click_reports_path, alert: t('resources.download_failed')
        end
      end
      # rubocop:enable Metrics/MethodLength

      private

      def set_link_click_report
        @link_click_report = BetterTogether::Metrics::LinkClickReport.find(params[:id])
      end

      def link_click_report_params
        params.require(:metrics_link_click_report).permit(
          :sort_by_total_clicks, :file_format,
          filters: %i[from_date to_date filter_internal]
        )
      end
    end
  end
end
