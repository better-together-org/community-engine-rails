# frozen_string_literal: true

module BetterTogether
  module Redirects
    # Bulk entry point for redirects: admin CSV import, rake tasks and the future seed registry.
    # Rows are hashes with :from_path, :to_path and optional :status, :preserve_query, :note.
    # Existing rows are only changed in :upsert mode; :add_only (default) skips them.
    # With dry_run (default) nothing is written and the report shows what would happen.
    class Importer
      Report = Struct.new(:created, :updated, :unchanged, :skipped, :errors, :dry_run, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(platform:, rows:, source: 'import', mode: :add_only, dry_run: true)
        @platform = platform
        @rows = rows
        @source = source
        @mode = mode.to_sym
        @dry_run = dry_run
      end

      def call
        report = Report.new(created: 0, updated: 0, unchanged: 0, skipped: 0, errors: [], dry_run: @dry_run)
        @rows.each_with_index { |row, index| import_row(row.to_h.symbolize_keys, index, report) }
        report
      end

      private

      def import_row(row, index, report) # rubocop:disable Metrics/AbcSize
        record = find_existing(row[:from_path]) || @platform.redirects.build
        existing = record.persisted?
        return report.skipped += 1 if existing && @mode != :upsert

        record.assign_attributes(attributes_for(row))
        return report.unchanged += 1 if existing && !record.changed?

        if record.valid?
          persist(record, existing, report)
        else
          report.errors << { row: index, from_path: row[:from_path], message: record.errors.full_messages.to_sentence }
        end
      end

      def persist(record, existing, report)
        record.save! unless @dry_run
        existing ? report.updated += 1 : report.created += 1
      end

      def find_existing(from_path)
        key = Redirect.normalize_path(from_path).downcase
        @platform.redirects.find_by(Redirect.arel_table[:from_path].lower.eq(key))
      end

      def attributes_for(row)
        attrs = row.slice(:from_path, :to_path, :status, :preserve_query, :note, :active)
        attrs[:status] = attrs[:status].to_i if attrs.key?(:status)
        attrs.merge(source: @source)
      end
    end
  end
end
