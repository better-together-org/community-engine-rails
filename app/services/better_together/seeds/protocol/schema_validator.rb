# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/ClassLength, Layout/LineLength

module BetterTogether
  module Seeds
    module Protocol
      # Validates a parsed document against a JSON Schema document (draft 2020-12 subset).
      # Supported: type, enum, const, required, properties, patternProperties,
      # additionalProperties (boolean or schema), items, minItems, minLength, minimum,
      # pattern, oneOf and local "$ref" (#/$defs/name). Unknown keywords are ignored.
      class SchemaValidator
        Violation = Data.define(:pointer, :message)

        TYPE_CHECKS = {
          'object' => ->(v) { v.is_a?(Hash) },
          'array' => ->(v) { v.is_a?(Array) },
          'string' => ->(v) { v.is_a?(String) },
          'integer' => ->(v) { v.is_a?(Integer) },
          'number' => ->(v) { v.is_a?(Numeric) },
          'boolean' => ->(v) { [true, false].include?(v) },
          'null' => lambda(&:nil?)
        }.freeze

        def initialize(schema)
          @root = schema
        end

        def validate(document)
          @violations = []
          check(document, @root, '')
          @violations
        end

        private

        def check(value, schema, pointer)
          schema = resolve(schema)
          return unless type_ok?(value, schema, pointer)

          add(pointer, "must be #{schema['const'].inspect}") if schema.key?('const') && value != schema['const']
          add(pointer, "must be one of #{schema['enum'].inspect}") if schema['enum'] && !schema['enum'].include?(value)
          check_one_of(value, schema, pointer) if schema['oneOf']
          check_string(value, schema, pointer) if value.is_a?(String)
          check_number(value, schema, pointer) if value.is_a?(Numeric)
          check_object(value, schema, pointer) if value.is_a?(Hash)
          check_array(value, schema, pointer) if value.is_a?(Array)
        end

        def resolve(schema)
          ref = schema['$ref']
          return schema unless ref

          ref.delete_prefix('#/').split('/').reduce(@root) { |node, part| node.fetch(part) }
        end

        def type_ok?(value, schema, pointer)
          types = Array(schema['type'])
          return true if types.empty? || types.any? { |t| TYPE_CHECKS.fetch(t).call(value) }

          add(pointer, "must be of type #{types.join(' or ')}")
          false
        end

        def check_one_of(value, schema, pointer)
          matches = schema['oneOf'].count { |option| matches?(value, option, pointer) }
          add(pointer, 'must match exactly one of the allowed shapes') unless matches == 1
        end

        def matches?(value, schema, pointer)
          saved = @violations
          @violations = []
          check(value, schema, pointer)
          @violations.empty?
        ensure
          @violations = saved
        end

        def check_string(value, schema, pointer)
          add(pointer, "must be at least #{schema['minLength']} characters") if schema['minLength'] && value.length < schema['minLength']
          return unless schema['pattern'] && !Regexp.new(schema['pattern']).match?(value)

          add(pointer, "must match #{schema['pattern']}")
        end

        def check_number(value, schema, pointer)
          return unless schema['minimum'] && value < schema['minimum']

          add(pointer, "must be at least #{schema['minimum']}")
        end

        def check_object(value, schema, pointer)
          Array(schema['required']).each do |name|
            add(join(pointer, name), 'is required') unless value.key?(name)
          end
          props = schema['properties'] || {}
          patterns = schema['patternProperties'] || {}
          value.each do |name, child|
            sub = props[name] || patterns.find { |re, _| Regexp.new(re).match?(name) }&.last
            if sub
              check(child, sub, join(pointer, name))
            elsif schema['additionalProperties'] == false
              add(join(pointer, name), 'is not allowed')
            elsif schema['additionalProperties'].is_a?(Hash)
              check(child, schema['additionalProperties'], join(pointer, name))
            end
          end
        end

        def check_array(value, schema, pointer)
          add(pointer, "must have at least #{schema['minItems']} items") if schema['minItems'] && value.length < schema['minItems']
          return unless schema['items']

          value.each_with_index { |item, index| check(item, schema['items'], join(pointer, index)) }
        end

        def join(pointer, part)
          "#{pointer}/#{part}"
        end

        def add(pointer, message)
          @violations << Violation.new(pointer, message)
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/ClassLength, Layout/LineLength
