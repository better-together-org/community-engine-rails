# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength

module BetterTogether
  module Seeds
    # Flat, comparable view of the fields a packet entry owns on a record. Keys look like
    # "attr:slug", "tr:fr:title", "ref:parent" and "position". Used to tell an unedited
    # planted record from one a steward changed, and to decide whether a plant is a no-op.
    module Snapshot
      module_function

      def keys_for(entry)
        keys = entry.attributes.keys.map { |a| "attr:#{a}" }
        entry.translations.each { |locale, fields| fields.each_key { |f| keys << "tr:#{locale}:#{f}" } }
        keys.concat(entry.refs.keys.map { |slot| "ref:#{slot}" })
        keys << 'position' unless entry.position.nil?
        keys
      end

      # Reads the named keys off a record.
      def read(record, definition, keys)
        keys.to_h { |key| [key, value_for(record, definition, key)] }
      end

      # What the entry will write, in the same normalised form as `read`.
      def proposed(scratch, definition, entry)
        RecordWriter.assign_fields(scratch, definition, entry)
        values = read(scratch, definition, keys_for(entry).grep_v(/\Aref:/))
        entry.refs.each { |slot, ref| values["ref:#{slot}"] = "#{ref['type']}:#{ref['key']}" }
        values
      end

      def fingerprint(flat)
        Digest::SHA256.hexdigest(JSON.generate(flat.sort.to_h))
      end

      def value_for(record, definition, key)
        kind, rest = key.split(':', 2)
        case kind
        when 'attr' then normalise(record.public_send(rest))
        when 'tr' then translation(record, rest)
        when 'ref' then reference_key(record, definition, rest)
        else normalise(record.public_send(definition.position_column || :position))
        end
      end

      def translation(record, rest)
        locale, field = rest.split(':', 2)
        Mobility.with_locale(locale) { normalise(record.public_send(field)) }
      end

      def reference_key(record, definition, slot)
        target = record.public_send(slot)
        return nil unless target

        ref = definition.references.fetch(slot.to_sym)
        type = ref.types.find { |t| target.is_a?(Registry.fetch(t).model) }
        column = type && Registry.fetch(type).natural_key_columns.first
        type ? "#{type}:#{target.public_send(column)}" : "#{target.class.name}:#{target.id}"
      end

      def normalise(value)
        value = value.to_plain_text if value.respond_to?(:to_plain_text)
        value = value.utc.iso8601(3) if value.respond_to?(:utc) && value.respond_to?(:iso8601)
        value.is_a?(String) ? value.strip : value.as_json
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength
