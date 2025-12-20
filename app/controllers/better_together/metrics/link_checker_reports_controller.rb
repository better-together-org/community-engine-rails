# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Controller for creating and downloading Link Checker reports
    class LinkCheckerReportsController < ApplicationController
      before_action :set_report, only: %i[download]

      def index
        authorize %i[metrics link_checker_report], :index?,
                  policy_class: BetterTogether::Metrics::LinkCheckerReportPolicy
        @link_checker_reports = BetterTogether::Metrics::LinkCheckerReport.order(created_at: :desc)

        if request.headers['Turbo-Frame'].present?
          render partial: 'better_together/metrics/link_checker_reports/index',
                 locals: { reports: @link_checker_reports },
                 layout: false
        else
          render :index
        end
      end

      def new
        authorize %i[metrics link_checker_report], :create?,
                  policy_class: BetterTogether::Metrics::LinkCheckerReportPolicy
        @link_checker_report = BetterTogether::Metrics::LinkCheckerReport.new
      end

      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/BlockLength
      def create
        authorize %i[metrics link_checker_report], :create?,
                  policy_class: BetterTogether::Metrics::LinkCheckerReportPolicy

        opts = {
          from_date: params.dig(:metrics_link_checker_report, :filters, :from_date),
          to_date: params.dig(:metrics_link_checker_report, :filters, :to_date),
          file_format: params.dig(:metrics_link_checker_report, :file_format) || 'csv'
        }

        @link_checker_report = BetterTogether::Metrics::LinkCheckerReport.create_and_generate!(**opts)

        respond_to do |format| # rubocop:todo Metrics/BlockLength
          if @link_checker_report.persisted?
            flash[:notice] = t('flash.generic.created', resource: t('resources.report'))
            format.html { redirect_to metrics_link_checker_reports_path, notice: flash[:notice] }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.prepend(
                  'link_checker_reports_table_body',
                  partial: 'better_together/metrics/link_checker_reports/link_checker_report',
                  locals: { link_checker_report: @link_checker_report }
                ),
                turbo_stream.replace(
                  'flash_messages',
                  partial: 'layouts/better_together/flash_messages',
                  locals: { flash: flash }
                ),
                turbo_stream.replace('new_link_checker_report',
                                     '<turbo-frame id="new_link_checker_report"></turbo-frame>')
              ]
            end
          else
            flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.report'))
            format.html { render :new, status: :unprocessable_content }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.update('form_errors', partial: 'layouts/errors', locals: { object: @link_checker_report }),
                turbo_stream.replace(
                  'flash_messages',
                  partial: 'layouts/better_together/flash_messages',
                  locals: { flash: flash }
                )
              ]
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Metrics/MethodLength
      def download
        authorize @link_checker_report, :download?

        if @link_checker_report.report_file.attached?
          BetterTogether::Metrics::TrackDownloadJob.perform_later(
            @link_checker_report,
            @link_checker_report.report_file.filename.to_s,
            @link_checker_report.report_file.content_type,
            @link_checker_report.report_file.byte_size,
            I18n.locale.to_s
          )

          send_data @link_checker_report.report_file.download,
                    filename: @link_checker_report.report_file.filename.to_s,
                    type: @link_checker_report.report_file.content_type,
                    disposition: 'attachment'

          return
        end

        redirect_to metrics_link_checker_reports_path, alert: t('resources.download_failed')
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      private

      def set_report
        @link_checker_report = BetterTogether::Metrics::LinkCheckerReport.find(params[:id])
      end
    end
  end
end
