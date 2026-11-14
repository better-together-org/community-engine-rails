# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength

module BetterTogether
  module Seeds
    # A protocol 2.0 packet read from a directory: parsed, schema-validated and normalised.
    # Loading never touches the database. Blob bytes are not read here (see BlobStore).
    class Packet
      Entry = Data.define(:type, :key, :attributes, :translations, :refs, :files, :position, :file, :index) do
        def id
          "#{type}:#{key}"
        end
      end

      MAX_YAML_BYTES = BetterTogether::Seed::MAX_FILE_SIZE
      REF_STRING = /\A(?<type>[a-z][a-z0-9_]*):(?<key>.+)\z/

      attr_reader :root, :envelope, :entries, :deletes, :report

      def self.load(path)
        new(path).tap(&:read)
      end

      def initialize(path)
        @root = Pathname.new(path.to_s).expand_path
        @report = Protocol::Report.new
        @entries = []
        @deletes = []
        @envelope = {}
      end

      def read
        return fail_load('packet directory not found') unless root.directory?
        return fail_load('packet contains a symbolic link') if root.glob('**/*', File::FNM_DOTMATCH).any?(&:symlink?)

        document = read_yaml(root.join('packet.yml'), 'packet.yml')
        return unless document

        Protocol::Validator.validate_envelope(document, report:)
        @envelope = (document['better_together'] || {}).deep_stringify_keys
        read_record_files if report.valid?
        @deletes = Array(envelope['deletes']).map { |d| d.slice('type', 'key') }
        self
      end

      def valid?
        report.valid?
      end

      def packet_meta
        envelope['packet'] || {}
      end

      def identifier
        packet_meta['id']
      end

      def mode
        packet_meta['mode']
      end

      def default_locale
        packet_meta['default_locale']
      end

      def locale_policy
        packet_meta['unsupported_locale_policy'] || 'fail'
      end

      def declared_platform_identifier
        packet_meta.dig('target', 'platform_identifier')
      end

      def dependencies
        Array(envelope.dig('seed_pack', 'dependencies'))
      end

      def blob_path(checksum)
        root.join('blobs', checksum)
      end

      private

      def read_record_files
        Array(packet_meta['records']).each do |relative|
          path = root.join(relative).expand_path
          next report.add_error(file: relative, message: 'path escapes the packet') unless path.to_s.start_with?("#{root}/")

          doc = read_yaml(path, relative)
          next unless doc

          Protocol::Validator.validate_records(doc, file: relative, report:)
          append_entries(doc, relative) if report.valid?
        end
      end

      def append_entries(doc, file)
        doc['records'].each_with_index do |record, index|
          @entries << Entry.new(
            type: doc['type'], key: record['key'], attributes: record['attributes'] || {},
            translations: record['translations'] || {}, refs: normalise_refs(record['refs'] || {}),
            files: record['files'] || [], position: record['position'], file:, index:
          )
        end
      end

      def normalise_refs(refs)
        refs.transform_values do |ref|
          next ref.slice('type', 'key', 'scope') if ref.is_a?(Hash)

          match = REF_STRING.match(ref)
          { 'type' => match[:type], 'key' => match[:key] }
        end
      end

      def read_yaml(path, label)
        return fail_load("#{label} is missing", label) unless path.file?
        return fail_load("#{label} exceeds #{MAX_YAML_BYTES} bytes", label) if path.size > MAX_YAML_BYTES

        Seed.safe_load_yaml_file(path.to_s)
      rescue SecurityError, Psych::SyntaxError => e
        fail_load(e.message, label)
      end

      def fail_load(message, file = 'packet.yml')
        report.add_error(file:, message:)
        nil
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength
