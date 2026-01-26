# frozen_string_literal: true

module BetterTogether
  module Metrics
    # LinkCheckerReport maintains a generated report for link-checker results
    # including counts by host and failures over time.
    # rubocop:disable Metrics/ClassLength
    class LinkCheckerReport < ApplicationRecord
      # Include URL helpers for generating edit links
      include Rails.application.routes.url_helpers
      include BetterTogether::Engine.routes.url_helpers

      # Associations
      belongs_to :creator, class_name: 'BetterTogether::Person', foreign_key: 'creator_id', inverse_of: :link_checker_reports, optional: true

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
        broken_links_details = collect_broken_links_details(base_scope)

        self.report_data = {
          by_host: by_host,
          invalid_by_host: invalid_by_host,
          failures_daily: failures_daily,
          broken_links: broken_links_details
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

      # Collect detailed information about broken links including record context
      def collect_broken_links_details(base_scope)
        broken_links = base_scope.where(valid_link: false)
                                 .includes(rich_text_links: [:rich_text])

        broken_links.flat_map { |link| build_broken_link_details(link) }
      end

      def build_broken_link_details(link)
        link.rich_text_links.map do |rt_link|
          build_single_link_detail(link, rt_link)
        end.compact
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build_single_link_detail(link, rt_link)
        rich_text = rt_link.rich_text
        return unless rich_text

        record = rich_text.record
        return unless record # Skip deleted records

        {
          record_type: humanize_record_type(record.class.name),
          record_identifier: record_identifier(record),
          field_name: field_name_from_rich_text(rich_text, record),
          url: link.url,
          status_code: link.last_status_code.to_s,
          error_message: link.last_error_message || 'Unknown error',
          last_checked_at: link.last_checked_at&.utc&.strftime('%Y-%m-%d %H:%M UTC') || 'Never',
          edit_instructions: edit_instructions_for(record),
          edit_url: edit_url_for(record)
        }
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def generate_csv_file
        file_path = Rails.root.join('tmp', build_filename)

        # rubocop:disable Metrics/BlockLength
        CSV.open(file_path, 'w') do |csv|
          # Report summary
          csv << ['Link Checker Report Summary']
          csv << ['Generated', Time.current.utc.strftime('%Y-%m-%d %H:%M UTC')]
          csv << ['Total Broken Links', total_broken_links]
          csv << []
          csv << ['Broken Links by Record Type']
          csv << []

          # Grouped broken links details
          grouped = broken_links_grouped_by_type
          grouped.each do |record_type, links|
            csv << ["#{record_type.upcase} (#{links.size} broken links)"]
            csv << ['Record', 'Field', 'Broken URL', 'Status', 'Error', 'Last Checked', 'Edit URL', 'Instructions']

            links.each do |link|
              csv << [
                link['record_identifier'] || link[:record_identifier],
                link['field_name'] || link[:field_name],
                link['url'] || link[:url],
                link['status_code'] || link[:status_code],
                link['error_message'] || link[:error_message],
                link['last_checked_at'] || link[:last_checked_at],
                link['edit_url'] || link[:edit_url] || 'N/A',
                link['edit_instructions'] || link[:edit_instructions]
              ]
            end

            csv << []
          end

          # Summary by host
          csv << ['Summary by Host']
          csv << ['Host', 'Total Links', 'Invalid Links']

          hosts = (report_data['by_host'] || report_data[:by_host] || {}).keys
          hosts.each do |host|
            total = (report_data['by_host'] || report_data[:by_host] || {})[host] || 0
            invalid = (report_data['invalid_by_host'] || report_data[:invalid_by_host] || {})[host] || 0
            csv << [host, total, invalid]
          end

          # Failures by date
          csv << []
          csv << ['Failures by Date']
          csv << ['Date', 'Invalid Count']
          (report_data['failures_daily'] || report_data[:failures_daily] || {}).each do |date, count|
            csv << [date.to_s, count]
          end
        end
        # rubocop:enable Metrics/BlockLength

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

      # Check if report has no broken links
      def no_broken_links?
        invalid_by_host = report_data&.dig('invalid_by_host') || report_data&.dig(:invalid_by_host) || {}
        invalid_by_host.values.sum.zero?
      end

      # Deprecated: Use no_broken_links? instead
      alias has_no_broken_links? no_broken_links?

      # Check if broken links have changed compared to another report
      def broken_links_changed_since?(other_report)
        return true if other_report.nil?

        current_invalid = extract_invalid_by_host
        previous_invalid = extract_invalid_by_host_from(other_report)

        # Compare the sets of broken links by host
        current_invalid != previous_invalid
      end

      def extract_invalid_by_host
        report_data&.dig('invalid_by_host') || report_data&.dig(:invalid_by_host) || {}
      end

      def extract_invalid_by_host_from(other_report)
        other_report.report_data&.dig('invalid_by_host') ||
          other_report.report_data&.dig(:invalid_by_host) || {}
      end

      # Get total count of broken links
      def total_broken_links
        invalid_by_host = report_data&.dig('invalid_by_host') || report_data&.dig(:invalid_by_host) || {}
        invalid_by_host.values.sum
      end

      # Group broken links by record type
      def broken_links_grouped_by_type
        broken_links = report_data&.dig('broken_links') || report_data&.dig(:broken_links) || []
        broken_links.group_by { |link| link['record_type'] || link[:record_type] }
      end

      # Humanize record type (strip namespace and format)
      def humanize_record_type(type)
        parts = type.to_s.split('::')
        # For nested modules like "BetterTogether::Content::Block", keep "Content Block"
        # For simple modules like "BetterTogether::Person", keep "Person"
        if parts.size > 2 && parts.first == 'BetterTogether'
          parts[1..].join(' ')
        else
          parts.last
        end
      end

      # Get identifier for a record
      def record_identifier(record)
        return record.name if record.respond_to?(:name)
        return record.title if record.respond_to?(:title)
        return record.identifier if record.respond_to?(:identifier)

        "ID: #{record.id}"
      end

      # Extract field name from ActionText rich_text
      def field_name_from_rich_text(rich_text, _record)
        rich_text.name&.humanize || 'Unknown'
      end

      # Generate edit instructions for record
      def edit_instructions_for(record)
        case record
        when BetterTogether::Person
          "Edit Person profile (#{record_identifier(record)})"
        when BetterTogether::Community
          "Edit Community (#{record_identifier(record)})"
        else
          "Edit #{record.class.name.demodulize} record"
        end
      end

      # Generate edit URL for a record
      def edit_url_for(record)
        platform = BetterTogether::Platform.host.first
        return nil unless platform

        url_options = build_url_options(platform)
        generate_record_edit_url(record, url_options)
      rescue StandardError => e
        Rails.logger.warn "Failed to generate edit URL for #{record.class.name}: #{e.message}"
        nil
      end

      def build_url_options(platform)
        host = platform.host_url.gsub(%r{^https?://}, '')
        protocol = platform.host_url.start_with?('https') ? 'https' : 'http'
        { locale: I18n.default_locale, host: host, protocol: protocol }
      end

      def generate_record_edit_url(record, url_options)
        case record
        when BetterTogether::Person
          edit_person_url(record, **url_options)
        when BetterTogether::Community
          edit_community_url(record, **url_options)
        when BetterTogether::Content::Block
          edit_content_block_url(record, **url_options)
        when BetterTogether::Page
          edit_page_url(record, **url_options)
        when BetterTogether::Post
          edit_post_url(record, **url_options)
        else
          polymorphic_url([:edit, record], **url_options)
        end
      end

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
    # rubocop:enable Metrics/ClassLength
  end
end
