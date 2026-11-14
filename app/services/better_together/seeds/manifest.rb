# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

module BetterTogether
  module Seeds
    # MANIFEST.json of a packet: every file's sha256, size, media type and owner. Verification
    # streams each file, so a 600 MB packet never needs to fit in memory.
    class Manifest
      Entry = Data.define(:path, :sha256, :size, :media_type, :owner, :license)
      READ_CHUNK = 1.megabyte

      attr_reader :entries

      def self.load(root)
        path = Pathname.new(root).join('MANIFEST.json')
        raise ArgumentError, 'MANIFEST.json is missing' unless path.file?

        new(JSON.parse(path.read))
      end

      def initialize(document)
        @document = document
        @entries = Array(document['files']).map do |f|
          Entry.new(f['path'], f['sha256'], f['size'], f['media_type'], f['owner'], f['license'])
        end
        @by_path = entries.index_by(&:path)
      end

      def entry_for_blob(checksum)
        @by_path["blobs/#{checksum}"]
      end

      # Verifies the manifest against the directory. Returns a Protocol::Report listing every
      # missing, unlisted, resized or altered file and every blob over the size policy.
      def verify(root, report: Protocol::Report.new)
        Protocol::Validator.validate_manifest(@document, report:)
        return report unless report.valid?

        root = Pathname.new(root)
        check_listed(root, report)
        check_unlisted(root, report)
        check_total(report)
        report
      end

      def self.sha256_of(path)
        digest = Digest::SHA256.new
        File.open(path, 'rb') { |io| while (chunk = io.read(READ_CHUNK)) do digest.update(chunk) end }
        digest.hexdigest
      end

      private

      def check_listed(root, report)
        entries.each do |entry|
          file = root.join(entry.path)
          next report.add_error(file: entry.path, message: 'listed in the manifest but missing') unless file.file?
          unless file.size == entry.size
            next report.add_error(file: entry.path,
                                  message: "size #{file.size} does not match manifest #{entry.size}")
          end
          if blob?(entry) && entry.size > BlobPolicy.max_blob_bytes
            next report.add_error(file: entry.path,
                                  message: "exceeds the #{BlobPolicy.max_blob_bytes} byte blob limit")
          end

          report.add_error(file: entry.path, message: 'sha256 does not match the manifest') unless self.class.sha256_of(file) == entry.sha256
          if blob?(entry) && entry.path != "blobs/#{entry.sha256}"
            report.add_error(file: entry.path,
                             message: 'blob file name must equal its sha256')
          end
        end
      end

      def check_unlisted(root, report)
        listed = @by_path.keys
        root.glob('**/*').select(&:file?).map { |f| f.relative_path_from(root).to_s }.each do |relative|
          next if listed.include?(relative) || relative.start_with?('MANIFEST.json')

          report.add_error(file: relative, message: 'present in the packet but not in the manifest')
        end
      end

      def check_total(report)
        total = entries.sum(&:size)
        return unless total > BlobPolicy.max_packet_bytes

        report.add_error(file: 'MANIFEST.json',
                         message: "packet is #{total} bytes, over the #{BlobPolicy.max_packet_bytes} byte limit")
      end

      def blob?(entry)
        entry.path.start_with?('blobs/')
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
