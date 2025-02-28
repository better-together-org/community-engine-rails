# frozen_string_literal: true

module BetterTogether
  module Metrics
    # PageViewReport records tracking instances of reports run against the BetterTogether::Metrics::PageView records
    class PageViewReport < ApplicationRecord # rubocop:todo Metrics/ClassLength
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

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def generate_report! # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        from_date = filters['from_date'].present? ? Date.parse(filters['from_date']) : nil
        to_date = filters['to_date'].present? ? Date.parse(filters['to_date']) : nil
        filter_pageable_type = filters['filter_pageable_type']

        report_by_type = {}

        # Build a base scope for filtering.
        base_scope = BetterTogether::Metrics::PageView.all
        base_scope = base_scope.where('viewed_at >= ?', from_date) if from_date
        base_scope = base_scope.where('viewed_at <= ?', to_date) if to_date
        base_scope = base_scope.where(pageable_type: filter_pageable_type) if filter_pageable_type.present?

        # Use distinct locales from the filtered PageView records.
        distinct_locales = base_scope.distinct.pluck(:locale).map(&:to_s).sort

        # Get distinct pageable types.
        types = base_scope.distinct.pluck(:pageable_type)
        types.each do |type| # rubocop:todo Metrics/BlockLength
          type_scope = base_scope.where(pageable_type: type)
          total_views = type_scope.group(:pageable_id).count
          locale_breakdowns = type_scope.group(:pageable_id, :locale).count
          page_url_map = type_scope.select(:pageable_id, :locale, :page_url)
                                   .group_by { |pv| [pv.pageable_id, pv.locale] }
                                   .transform_values { |views| views.first.page_url }
          ids = total_views.keys
          records = type.constantize.where(id: ids).index_by(&:id)
          sorted_total_views = total_views.sort_by { |_, count| -count }

          # rubocop:todo Metrics/BlockLength
          report_by_type[type] = sorted_total_views.each_with_object({}) do |(pageable_id, views_count), hash|
            breakdown = locale_breakdowns.each_with_object({}) do |((pid, locale), count), b|
              b[locale.to_s] = { count: count, page_url: page_url_map[[pid, locale]] } if pid == pageable_id
            end

            record_obj = records[pageable_id]
            # Fetch friendly names for the distinct locales.
            friendly_names = {}
            distinct_locales.each do |locale|
              friendly_names[locale] =
                if record_obj.present?
                  Mobility.with_locale(locale) do
                    if record_obj.respond_to?(:title) && record_obj.title.present?
                      record_obj.title
                    elsif record_obj.respond_to?(:name) && record_obj.name.present?
                      record_obj.name
                    else
                      "#{type} ##{pageable_id}"
                    end
                  end
                else
                  "#{type} ##{pageable_id}"
                end
            end

            hash[pageable_id] = {
              total_views: views_count,
              locale_breakdown: breakdown,
              friendly_names: friendly_names
            }
          end
          # rubocop:enable Metrics/BlockLength
        end

        generated_report = if sort_by_total_views
                             flattened = []
                             report_by_type.each do |type, records|
                               records.each do |pageable_id, data|
                                 flattened << data.merge(pageable_type: type, pageable_id: pageable_id)
                               end
                             end
                             flattened.sort_by { |record| -record[:total_views] }
                           else
                             report_by_type
                           end

        self.report_data = generated_report
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      # This method generates the CSV file and attaches it using a human-friendly filename.
      def export_file! # rubocop:todo Metrics/MethodLength
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
        # Remove the temporary file if it exists.
        File.delete(file_path) if file_path && File.exist?(file_path)
      end

      private

      # Purge the attached report file after the record is destroyed.
      def purge_report_file
        report_file.purge_later if report_file.attached?
      end

      def export_file_if_report_exists
        export_file! if report_data.present? && !report_data.empty?
      end

      # Helper method to generate the CSV file.
      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def generate_csv_file # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        from_date = filters['from_date'].present? ? Date.parse(filters['from_date']) : nil
        to_date = filters['to_date'].present? ? Date.parse(filters['to_date']) : nil
        filter_pageable_type = filters['filter_pageable_type']

        base_scope = BetterTogether::Metrics::PageView.all
        base_scope = base_scope.where('viewed_at >= ?', from_date) if from_date
        base_scope = base_scope.where('viewed_at <= ?', to_date) if to_date
        base_scope = base_scope.where(pageable_type: filter_pageable_type) if filter_pageable_type.present?

        locales = base_scope.distinct.pluck(:locale).map(&:to_s).sort

        header = ['Pageable Type', 'Pageable ID']
        locales.each { |locale| header << "Friendly Name (#{locale})" }
        header << 'Total Views'
        locales.each do |locale|
          header << "Count (#{locale})"
        end
        locales.each do |locale|
          header << "Page URL (#{locale})"
        end

        file_path = Rails.root.join('tmp', build_filename)
        CSV.open(file_path, 'w') do |csv| # rubocop:todo Metrics/BlockLength
          csv << header

          if sort_by_total_views
            report_data.each do |data|
              row = []
              row << data['pageable_type']
              row << data['pageable_id']
              friendly_names = locales.map { |locale| data['friendly_names'][locale] }
              row.concat(friendly_names)
              row << data['total_views']
              count_values = locales.map { |locale| data['locale_breakdown'][locale].try(:[], 'count') }
              row.concat(count_values)
              url_values = locales.map { |locale| data['locale_breakdown'][locale].try(:[], 'page_url') }
              row.concat(url_values)
              csv << row
            end
          else
            report_data.each do |type, records|
              records.each do |pageable_id, data|
                row = []
                row << type
                row << pageable_id
                friendly_names = locales.map { |locale| data['friendly_names'][locale] }
                row.concat(friendly_names)
                row << data['total_views']
                count_values = locales.map { |locale| data['locale_breakdown'][locale].try(:[], 'count') }
                row.concat(count_values)
                url_values = locales.map { |locale| data['locale_breakdown'][locale].try(:[], 'page_url') }
                row.concat(url_values)
                csv << row
              end
            end
          end
        end

        file_path
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      # This method builds a human-friendly filename based on the applied filters,
      # the sort toggle, and the current time.
      # rubocop:todo Metrics/MethodLength
      def build_filename # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        filters_summary = []
        if filters['from_date'].present?
          filters_summary << "from_#{Date.parse(filters['from_date']).strftime('%Y-%m-%d')}"
        end
        filters_summary << "to_#{Date.parse(filters['to_date']).strftime('%Y-%m-%d')}" if filters['to_date'].present?
        filters_summary << "type_#{filters['filter_pageable_type']}" if filters['filter_pageable_type'].present?
        filters_summary = filters_summary.join('_')
        filters_summary = 'all' if filters_summary.blank?
        sorting_segment = sort_by_total_views ? 'sorted' : 'grouped'
        timestamp = Time.current.strftime('%Y-%m-%d_%H%M%S')
        "PageViewReport_#{timestamp}_#{filters_summary}_#{sorting_segment}.#{file_format}"
      end
      # rubocop:enable Metrics/MethodLength

      #
      # Class Methods
      #
      class << self
        def create_and_generate!(from_date: nil, to_date: nil, filter_pageable_type: nil, sort_by_total_views: false,
                                 file_format: 'csv')
          filters = {}
          filters['from_date'] = from_date if from_date.present?
          filters['to_date'] = to_date if to_date.present?
          filters['filter_pageable_type'] = filter_pageable_type if filter_pageable_type.present?

          create!(
            filters: filters,
            sort_by_total_views: sort_by_total_views,
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
