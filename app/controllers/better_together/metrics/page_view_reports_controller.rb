# frozen_string_literal: true

module BetterTogether
  module Metrics
    # rubocop:todo Layout/LineLength
    # Manage PageViewReport records tracking instances of reports run against the BetterTogether::Metrics::PageView records
    # rubocop:enable Layout/LineLength
    class PageViewReportsController < ApplicationController
      before_action :set_page_view_report, only: [:download]

      # GET /metrics/page_view_reports
      def index
        @page_view_reports = BetterTogether::Metrics::PageViewReport.order(created_at: :desc)
        if request.headers['Turbo-Frame'].present?
          render partial: 'better_together/metrics/page_view_reports/index',
                 locals: { page_view_reports: @page_view_reports }, layout: false
        else
          render :index
        end
      end

      # GET /metrics/page_view_reports/new
      def new
        @page_view_report = BetterTogether::Metrics::PageViewReport.new
        @pageable_types = BetterTogether::Metrics::PageView.distinct.pluck(:pageable_type).sort
      end

      # POST /metrics/page_view_reports
      def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        opts = {
          from_date: page_view_report_params.dig(:filters, :from_date),
          to_date: page_view_report_params.dig(:filters, :to_date),
          filter_pageable_type: page_view_report_params.dig(:filters, :filter_pageable_type),
          sort_by_total_views: page_view_report_params[:sort_by_total_views],
          file_format: page_view_report_params[:file_format]
        }

        @page_view_report = BetterTogether::Metrics::PageViewReport.create_and_generate!(**opts)

        respond_to do |format| # rubocop:todo Metrics/BlockLength
          if @page_view_report.persisted?
            flash[:notice] = t('flash.generic.created', resource: t('resources.report'))
            format.html { redirect_to metrics_page_view_reports_path, notice: flash[:notice] }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.prepend('page_view_reports_table_body',
                                     partial: 'better_together/metrics/page_view_reports/page_view_report',
                                     locals: { page_view_report: @page_view_report }),
                turbo_stream.replace('flash_messages',
                                     partial: 'layouts/better_together/flash_messages',
                                     locals: { flash: flash }),
                # rubocop:todo Layout/LineLength
                turbo_stream.replace('new_report', '<turbo-frame id="new_report"></turbo-frame>') # Clear the new report form frame
                # rubocop:enable Layout/LineLength
              ]
            end
          else
            flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.report'))
            format.html { render :new, status: :unprocessable_entity }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.update('form_errors',
                                    partial: 'layouts/errors',
                                    locals: { object: @page_view_report }),
                turbo_stream.replace('flash_messages',
                                     partial: 'layouts/better_together/flash_messages',
                                     locals: { flash: flash })
              ]
            end
          end
        end
      end

      # GET /metrics/page_view_reports/:id/download
      def download # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        report = @page_view_report
        if report.report_file.attached?
          # Log the download via a background job.
          BetterTogether::Metrics::TrackDownloadJob.perform_later(
            report, # Full namespaced model
            report.report_file.filename.to_s,              # Filename
            report.report_file.content_type,               # Content type
            report.report_file.byte_size,                  # File size
            I18n.locale.to_s # Locale
          )

          send_data report.report_file.download,
                    filename: report.report_file.filename.to_s,
                    type: report.report_file.content_type,
                    disposition: 'attachment'
        else
          redirect_to metrics_page_view_reports_path, alert: t('resources.download_failed')
        end
      end

      private

      def set_page_view_report
        @page_view_report = BetterTogether::Metrics::PageViewReport.find(params[:id])
      end

      def page_view_report_params
        params.require(:metrics_page_view_report).permit(
          :sort_by_total_views, :file_format,
          filters: %i[from_date to_date filter_pageable_type]
        )
      end
    end
  end
end
