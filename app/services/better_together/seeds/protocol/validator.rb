# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/ClassLength, Layout/LineLength

module BetterTogether
  module Seeds
    module Protocol
      # Static validation of seed packet documents (protocol 2.0) and legacy 1.0 envelopes.
      # It only reads the documents it is given; nothing is written and no database is touched.
      # Reference resolution against a platform and blob byte verification belong to the planner.
      class Validator
        SCHEMA_DIR = BetterTogether::Engine.root.join('config/seeds/schema')
        LEGACY_ENVELOPE_FIELDS = %w[type identifier created_by created_at description origin].freeze

        def self.schema(name)
          @schemas ||= {}
          @schemas[name] ||= JSON.parse(SCHEMA_DIR.join("#{name}.schema.json").read)
        end

        # Validates an envelope hash (with or without the root key). Version 1.x keeps
        # the original rules; version 2.x must satisfy the 2.0 schema.
        def self.validate_envelope(document, root_key: Seed::DEFAULT_ROOT_KEY, report: Report.new)
          body = document.is_a?(Hash) ? (document[root_key] || document[root_key.to_sym]) : nil
          unless body.is_a?(Hash)
            report.add_error(file: 'packet.yml', field: root_key, message: "missing root key #{root_key}")
            return report
          end

          body = body.deep_stringify_keys
          if body['version'].to_s.start_with?('2.')
            violations(body, 'envelope', 'packet.yml', report)
            validate_packet_rules(body, report)
          else
            validate_legacy_envelope(body, report)
          end
          report
        end

        # Validates one parsed records/*.yml document.
        def self.validate_records(document, file: 'records', report: Report.new)
          doc = document.is_a?(Hash) ? document.deep_stringify_keys : document
          SchemaValidator.new(schema('records')).validate(doc).each do |v|
            record, field = locate(doc, v.pointer)
            report.add_error(file:, record:, field:, message: v.message)
          end
          validate_record_rules(doc, file, report) if doc.is_a?(Hash) && doc['records'].is_a?(Array)
          report
        end

        # Validates a parsed MANIFEST.json document.
        def self.validate_manifest(document, report: Report.new)
          violations(document.deep_stringify_keys, 'manifest', 'MANIFEST.json', report)
          paths = Array(document.deep_stringify_keys['files']).pluck('path')
          paths.tally.each do |path, count|
            report.add_error(file: 'MANIFEST.json', field: path, message: 'is listed more than once') if count > 1
          end
          report
        end

        def self.violations(document, schema_name, file, report)
          SchemaValidator.new(schema(schema_name)).validate(document).each do |v|
            report.add_error(file:, field: v.pointer, message: v.message)
          end
        end

        def self.validate_legacy_envelope(body, report)
          report.add_error(file: 'packet.yml', field: '/version', message: 'is required') unless body.key?('version')
          report.add_error(file: 'packet.yml', field: '/seed', message: 'is required') unless body['seed'].is_a?(Hash)
          return unless body['seed'].is_a?(Hash)

          (LEGACY_ENVELOPE_FIELDS - body['seed'].keys).each do |field|
            report.add_error(file: 'packet.yml', field: "/seed/#{field}", message: 'is required')
          end
          return if body['version'].to_s.match?(/\A\d+\.\d+/)

          report.add_error(file: 'packet.yml', field: '/version', message: "invalid version #{body['version']}, expected X.Y")
        end

        # Rules a schema cannot express: locale membership and duplicate record files.
        def self.validate_packet_rules(body, report)
          packet = body['packet']
          return unless packet.is_a?(Hash)

          default = packet['default_locale']
          if default && packet['locales'].is_a?(Array) && packet['locales'].exclude?(default)
            report.add_error(file: 'packet.yml', field: '/packet/default_locale', message: 'must be listed in locales')
          end
          Array(packet['records']).tally.each do |path, count|
            report.add_error(file: 'packet.yml', field: '/packet/records', message: "#{path} is listed more than once") if count > 1
          end
          deps = Array(body.dig('seed_pack', 'dependencies'))
          return unless deps.include?(body.dig('seed', 'identifier'))

          report.add_error(file: 'packet.yml', field: '/seed_pack/dependencies', message: 'a pack cannot depend on itself')
        end

        # Rules a schema cannot express: key uniqueness per type, file ownership.
        def self.validate_record_rules(doc, file, report)
          doc['records'].each_with_index do |record, index|
            next unless record.is_a?(Hash)

            record['files']&.each do |entry|
              next unless entry.is_a?(Hash) && entry['blob'] && entry['checksum']
              next if entry['blob'] == "blobs/#{entry['checksum']}"

              report.add_error(file:, record: record['key'] || index, field: 'files',
                               message: 'blob path must equal blobs/<checksum>')
            end
          end
          doc['records'].filter_map { |r| r['key'] if r.is_a?(Hash) }.tally.each do |key, count|
            report.add_error(file:, record: key, field: 'key', message: "duplicate key in #{doc['type']}") if count > 1
          end
        end

        # Maps a JSON pointer such as /records/2/attributes to [record key or index, field].
        def self.locate(doc, pointer)
          parts = pointer.split('/').drop(1)
          return [nil, pointer] unless parts.first == 'records' && parts[1]&.match?(/\A\d+\z/)

          index = parts[1].to_i
          item = doc.is_a?(Hash) && doc['records'].is_a?(Array) ? doc['records'][index] : nil
          record = item.is_a?(Hash) && item['key'] ? item['key'] : index
          [record, "/#{parts.drop(2).join('/')}".chomp('/')]
        end

        private_class_method :violations, :validate_legacy_envelope, :validate_packet_rules,
                             :validate_record_rules, :locate
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/ClassLength, Layout/LineLength
