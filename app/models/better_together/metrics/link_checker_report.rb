# frozen_string_literal: true

module BetterTogether
  module Metrics
    # LinkCheckerReport maintains a generated report for link-checker results
    # including counts by host and failures over time.
    class LinkCheckerReport < ApplicationRecord
      has_one_attached :report_file

      validates :file_format, presence: true
      attribute :filters, :jsonb, default: {}

      before_create :generate_report!
      after_create_commit :export_file_if_report_exists
      after_destroy_commit :purge_report_file

      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Metrics/MethodLength
      def generate_report!
        from_date = filters['from_date'].present? ? Date.parse(filters['from_date']) : nil
        to_date = filters['to_date'].present? ? Date.parse(filters['to_date']) : nil

        base_scope = BetterTogether::Content::Link.all
        base_scope = base_scope.where('last_checked_at >= ?', from_date) if from_date
        base_scope = base_scope.where('last_checked_at <= ?', to_date) if to_date

        by_host = base_scope.group(:host).count
        invalid_by_host = base_scope.where(valid_link: false).group(:host).count
        failures_daily = base_scope.where(valid_link: false).group_by_day(:last_checked_at).count

        self.report_data = {
          by_host: by_host,
          invalid_by_host: invalid_by_host,
          failures_daily: failures_daily
        }
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/MethodLength
      def export_file!
        file_path = if file_format == 'csv'
                      generate_csv_file
                    else
                      raise "Unsupported file format: #{file_format}"
                    end

        report_file.attach(
          io: File.open(file_path),
          filename: build_filename,
          content_type: file_format == 'csv' ? 'text/csv' : 'application/octet-stream'
        )
      ensure
        File.delete(file_path) if file_path && File.exist?(file_path)
      end
      # rubocop:enable Metrics/MethodLength

      private

      def purge_report_file
        report_file.purge_later if report_file.attached?
      end

      def export_file_if_report_exists
        export_file! if report_data.present? && !report_data.empty?
      end

      # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def generate_csv_file
        file_path = Rails.root.join('tmp', build_filename)

        CSV.open(file_path, 'w') do |csv|
          csv << ['Host', 'Total Links', 'Invalid Links']

          hosts = (report_data['by_host'] || report_data[:by_host] || {}).keys
          hosts.each do |host|
            total = (report_data['by_host'] || report_data[:by_host] || {})[host] || 0
            invalid = (report_data['invalid_by_host'] || report_data[:invalid_by_host] || {})[host] || 0
            csv << [host, total, invalid]
          end

          csv << []
          csv << ['Date', 'Invalid Count']
          (report_data['failures_daily'] || report_data[:failures_daily] || {}).each do |date, count|
            csv << [date.to_s, count]
          end
        end

        file_path
      end
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/AbcSize
      # rubocop:todo Metrics/MethodLength
      def build_filename
        filters_summary = []

        if filters['from_date'].present?
          from_stamp = Date.parse(filters['from_date']).strftime('%Y-%m-%d')
          filters_summary << "from_#{from_stamp}"
        end

        if filters['to_date'].present?
          to_stamp = Date.parse(filters['to_date']).strftime('%Y-%m-%d')
          filters_summary << "to_#{to_stamp}"
        end

        filters_summary = filters_summary.join('_')
        filters_summary = 'all' if filters_summary.blank?

        timestamp = Time.current.strftime('%Y-%m-%d_%H%M%S')

        "LinkCheckerReport_#{timestamp}_#{filters_summary}.#{file_format}"
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      class << self
        def create_and_generate!(from_date: nil, to_date: nil, file_format: 'csv')
          filters = {}
          filters['from_date'] = from_date if from_date.present?
          filters['to_date'] = to_date if to_date.present?

          create!(filters: filters, file_format: file_format)
        end

        def export_existing!(id)
          report = find(id)
          report.export_file_if_report_exists
          report
        end
      end
    end
  end
end
