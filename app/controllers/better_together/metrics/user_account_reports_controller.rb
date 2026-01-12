# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Controller for creating and downloading User Account reports
    # rubocop:disable Metrics/ClassLength
    class UserAccountReportsController < ApplicationController
      before_action :set_report, only: %i[download destroy]

      def index
        authorize %i[metrics user_account_report], :index?,
                  policy_class: BetterTogether::Metrics::UserAccountReportPolicy
        @user_account_reports = BetterTogether::Metrics::UserAccountReport.order(created_at: :desc)

        if request.headers['Turbo-Frame'].present?
          render partial: 'better_together/metrics/user_account_reports/index',
                 locals: { user_account_reports: @user_account_reports },
                 layout: false
        else
          render :index
        end
      end

      def new
        authorize %i[metrics user_account_report], :create?,
                  policy_class: BetterTogether::Metrics::UserAccountReportPolicy
        @user_account_report = BetterTogether::Metrics::UserAccountReport.new
      end

      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/BlockLength
      def create
        authorize %i[metrics user_account_report], :create?,
                  policy_class: BetterTogether::Metrics::UserAccountReportPolicy

        opts = {
          from_date: params.dig(:metrics_user_account_report, :filters, :from_date),
          to_date: params.dig(:metrics_user_account_report, :filters, :to_date),
          file_format: params.dig(:metrics_user_account_report, :file_format) || 'csv',
          creator: helpers.current_person
        }

        @user_account_report = BetterTogether::Metrics::UserAccountReport.create_and_generate!(**opts)

        respond_to do |format| # rubocop:todo Metrics/BlockLength
          if @user_account_report.persisted?
            flash[:notice] = t('flash.generic.created', resource: t('resources.report'))
            format.html { redirect_to metrics_user_account_reports_path, notice: flash[:notice] }
            format.turbo_stream do
              # Check if this is the first report to decide whether to replace empty state or prepend to table
              @user_account_reports = BetterTogether::Metrics::UserAccountReport.all
              is_first_report = @user_account_reports.count == 1

              if is_first_report
                # Replace the entire content section (empty state -> table)
                render turbo_stream: [
                  turbo_stream.replace(
                    'user_account_reports_content',
                    partial: 'better_together/metrics/user_account_reports/reports_content',
                    locals: { user_account_reports: @user_account_reports }
                  ),
                  turbo_stream.replace(
                    'flash_messages',
                    partial: 'layouts/better_together/flash_messages',
                    locals: { flash: flash }
                  ),
                  turbo_stream.replace('new_user_account_report',
                                       '<turbo-frame id="new_user_account_report"></turbo-frame>')
                ]
              else
                # Just prepend to existing table
                render turbo_stream: [
                  turbo_stream.prepend(
                    'user_account_reports_table_body',
                    partial: 'better_together/metrics/user_account_reports/user_account_report',
                    locals: { user_account_report: @user_account_report }
                  ),
                  turbo_stream.replace(
                    'flash_messages',
                    partial: 'layouts/better_together/flash_messages',
                    locals: { flash: flash }
                  ),
                  turbo_stream.replace('new_user_account_report',
                                       '<turbo-frame id="new_user_account_report"></turbo-frame>')
                ]
              end
            end
          else
            flash.now[:alert] = t('flash.generic.error_create', resource: t('resources.report'))
            format.html { render :new, status: :unprocessable_content }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.update('form_errors', partial: 'layouts/errors', locals: { object: @user_account_report }),
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
        authorize @user_account_report, :download?

        if @user_account_report.report_file.attached?
          BetterTogether::Metrics::TrackDownloadJob.perform_later(
            @user_account_report,
            @user_account_report.report_file.filename.to_s,
            @user_account_report.report_file.content_type,
            @user_account_report.report_file.byte_size,
            I18n.locale.to_s
          )

          send_data @user_account_report.report_file.download,
                    filename: @user_account_report.report_file.filename.to_s,
                    type: @user_account_report.report_file.content_type,
                    disposition: 'attachment'

          return
        end

        redirect_to metrics_user_account_reports_path, alert: t('resources.download_failed')
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def destroy
        authorize @user_account_report, :destroy?

        @user_account_report.destroy

        respond_to do |format|
          format.html { redirect_to metrics_user_account_reports_path, notice: t('flash.generic.destroyed', resource: t('resources.report')) }
          format.turbo_stream do
            # Check if this was the last report to decide whether to show empty state
            @user_account_reports = BetterTogether::Metrics::UserAccountReport.all
            is_last_report = @user_account_reports.empty?

            if is_last_report
              # Replace the entire content section (table -> empty state)
              render turbo_stream: [
                turbo_stream.replace(
                  'user_account_reports_content',
                  partial: 'better_together/metrics/user_account_reports/reports_content',
                  locals: { user_account_reports: @user_account_reports }
                ),
                turbo_stream.replace(
                  'flash_messages',
                  partial: 'layouts/better_together/flash_messages',
                  locals: { flash: { notice: t('flash.generic.destroyed', resource: t('resources.report')) } }
                )
              ]
            else
              # Just remove the row
              render turbo_stream: [
                turbo_stream.remove("user_account_report_#{@user_account_report.id}"),
                turbo_stream.replace(
                  'flash_messages',
                  partial: 'layouts/better_together/flash_messages',
                  locals: { flash: { notice: t('flash.generic.destroyed', resource: t('resources.report')) } }
                )
              ]
            end
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      def set_report
        @user_account_report = BetterTogether::Metrics::UserAccountReport.find(params[:id])
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
