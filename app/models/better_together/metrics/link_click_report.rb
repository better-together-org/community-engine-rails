# frozen_string_literal: true

module BetterTogether
  module Metrics
    # LinkClickReport records tracking instances of reports run against the BetterTogether::Metrics::LinkClick records.
    class LinkClickReport < ApplicationRecord
      # Active Storage attachment for the generated file.
      has_one_attached :report_file

      # Validations.
      validates :file_format, presence: true
      attribute :filters, :jsonb, default: {}

      # Callbacks to generate report data before creation, export file after commit,
      # and purge the attached file after destroy.
      before_create :generate_report!
      after_create_commit :export_file_if_report_exists
      after_destroy_commit :purge_report_file

      #
      # Instance Methods
      #

      # Generates the report data for LinkClick metrics.
      def generate_report!
        from_date = filters['from_date'].present? ? Date.parse(filters['from_date']) : nil
        to_date   = filters['to_date'].present?   ? Date.parse(filters['to_date'])   : nil
        filter_internal = filters['filter_internal'].present? ? filters['filter_internal'] : nil

        report_by_clicks = {}

        # Build a base scope for filtering LinkClick records.
        base_scope = BetterTogether::Metrics::LinkClick.all
        base_scope = base_scope.where('clicked_at >= ?', from_date) if from_date
        base_scope = base_scope.where('clicked_at <= ?', to_date) if to_date
        base_scope = base_scope.where(internal: filter_internal) unless filter_internal.nil?

        # Get distinct locales present in the filtered LinkClick records.
        distinct_locales = base_scope.distinct.pluck(:locale).map(&:to_s).sort

        # Group by URL.
        urls = base_scope.distinct.pluck(:url)
        urls.each do |url|
          url_scope   = base_scope.where(url: url)
          total_clicks = url_scope.count
          locale_breakdowns = url_scope.group(:locale).count
          page_url = url_scope.select(:page_url).first&.page_url

          # Build friendly names; for link clicks we’ll simply use the URL.
          friendly_names = {}
          distinct_locales.each do |locale|
            friendly_names[locale] = url
          end

          report_by_clicks[url] = {
            total_clicks: total_clicks,
            locale_breakdown: locale_breakdowns,
            friendly_names: friendly_names,
            page_url: page_url
          }
        end

        generated_report = if sort_by_total_clicks
                             report_by_clicks.sort_by { |_, data| -data[:total_clicks] }.to_h
                           else
                             report_by_clicks
                           end

        self.report_data = generated_report
      end

      # Generates the CSV file and attaches it using a human-friendly filename.
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

      private

      # Purges the attached report file after the record is destroyed.
      def purge_report_file
        report_file.purge_later if report_file.attached?
      end

      def export_file_if_report_exists
        export_file! if report_data.present? && !report_data.empty?
      end

      # Helper method to generate the CSV file.
      def generate_csv_file
        from_date = filters['from_date'].present? ? Date.parse(filters['from_date']) : nil
        to_date   = filters['to_date'].present?   ? Date.parse(filters['to_date'])   : nil
        filter_internal = filters['filter_internal']

        base_scope = BetterTogether::Metrics::LinkClick.all
        base_scope = base_scope.where('clicked_at >= ?', from_date) if from_date
        base_scope = base_scope.where('clicked_at <= ?', to_date) if to_date
        base_scope = base_scope.where(internal: filter_internal) unless filter_internal.nil?

        locales = base_scope.distinct.pluck(:locale).map(&:to_s).sort

        header = ['URL']
        locales.each { |locale| header << "Friendly Name (#{locale})" }
        header << 'Total Clicks'
        locales.each do |locale|
          header << "Count (#{locale})"
        end
        header << 'Page URL'

        file_path = Rails.root.join('tmp', build_filename)
        CSV.open(file_path, 'w') do |csv|
          csv << header

          report_data.each do |url, data|
            row = []
            row << url
            friendly_names = locales.map { |locale| data['friendly_names'][locale] }
            row.concat(friendly_names)
            row << data['total_clicks']
            count_values = locales.map { |locale| data['locale_breakdown'][locale] }
            row.concat(count_values)
            row << data['page_url']
            csv << row
          end
        end

        file_path
      end

      # Builds a human-friendly filename based on the applied filters, the sort toggle, and the current time.
      def build_filename
        filters_summary = []
        if filters['from_date'].present?
          filters_summary << "from_#{Date.parse(filters['from_date']).strftime('%Y-%m-%d')}"
        end
        filters_summary << "to_#{Date.parse(filters['to_date']).strftime('%Y-%m-%d')}" if filters['to_date'].present?
        filters_summary << "internal_#{filters['filter_internal']}" unless filters['filter_internal'].nil?
        filters_summary = filters_summary.join('_')
        filters_summary = 'all' if filters_summary.blank?
        sorting_segment = sort_by_total_clicks ? 'sorted' : 'grouped'
        timestamp = Time.current.strftime('%Y-%m-%d_%H%M%S')
        "LinkClickReport_#{timestamp}_#{filters_summary}_#{sorting_segment}.#{file_format}"
      end

      #
      # Class Methods
      #
      class << self
        def create_and_generate!(from_date: nil, to_date: nil, filter_internal: nil, sort_by_total_clicks: false,
                                 file_format: 'csv')
          filters = {}
          filters['from_date'] = from_date if from_date.present?
          filters['to_date']   = to_date   if to_date.present?
          filters['filter_internal'] = filter_internal unless filter_internal.nil?

          create!(
            filters: filters,
            sort_by_total_clicks: sort_by_total_clicks,
            file_format: file_format
          )
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
