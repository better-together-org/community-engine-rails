# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength

module BetterTogether
  module Seeds
    # Writes a packet entry onto a record. Only registry-declared fields are ever assigned.
    module RecordWriter
      module_function

      def build(definition, entry, platform)
        klass = definition.model
        chosen = entry.attributes['type']
        if definition.sti_column && chosen
          raise ArgumentError, "#{chosen} is not an allowed #{definition.name} type" unless definition.sti_allowed.call.include?(chosen)

          klass = chosen.constantize
        end
        record = klass.new
        record.platform = platform if definition.platform_column && record.respond_to?(:platform=)
        record.public_send("#{definition.natural_key_columns.first}=", entry.key) if definition.by_refs.empty?
        record
      end

      def assign_fields(record, definition, entry)
        entry.attributes.except(definition.sti_column.to_s).each { |name, value| record.public_send("#{name}=", value) }
        entry.translations.each do |locale, fields|
          Mobility.with_locale(locale) { fields.each { |name, value| record.public_send("#{name}=", value) } }
        end
        record.public_send("#{definition.position_column}=", entry.position) if definition.position_column && !entry.position.nil?
        record
      end

      def assign_refs(record, entry, targets)
        entry.refs.each_key { |slot| record.public_send("#{slot}=", targets.fetch(slot)) }
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength
