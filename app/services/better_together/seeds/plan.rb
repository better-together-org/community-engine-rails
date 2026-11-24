# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength

module BetterTogether
  module Seeds
    # Result of planning: one Item per record with the action that applying would take.
    # `to_h` is the structured report; a dry run returns it without writing anything.
    class Plan
      ACTIONS = %i[create update unchanged skipped_edited delete].freeze
      Item = Data.define(:entry, :type, :key, :action, :detail, :record_id, :planted)

      attr_reader :items, :errors, :warnings, :platform, :packet

      def initialize(packet:, platform:)
        @packet = packet
        @platform = platform
        @items = []
        @errors = []
        @warnings = []
      end

      def add_error(record:, message:, field: nil)
        errors << { record:, field:, message: }
      end

      def add_warning(record:, message:, field: nil)
        warnings << { record:, field:, message: }
      end

      def ok?
        errors.empty?
      end

      def counts
        tally = items.map(&:action).tally
        { created: tally[:create].to_i, updated: tally[:update].to_i, skipped_edited: tally[:skipped_edited].to_i,
          unchanged: tally[:unchanged].to_i, deleted: tally[:delete].to_i }
      end

      def to_h(dry_run: true)
        counts.merge(
          dry_run:, packet: packet.identifier, mode: packet.mode, platform: platform&.identifier,
          errors:, warnings:,
          records: items.map { |i| { record: i.entry ? i.entry.id : "#{i.type}:#{i.key}", action: i.action, detail: i.detail }.compact }
        )
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength
