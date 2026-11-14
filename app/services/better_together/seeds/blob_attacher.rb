# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

module BetterTogether
  module Seeds
    # Attaches a record entry's files from a packet's blobs. Matches the `attach_files:`
    # contract of Seeds::Applier: call(record:, entry:). Each blob is re-hashed immediately
    # before it is read (a file changed after manifest verification is rejected) and streamed
    # into Active Storage. A file already attached with identical bytes is left alone.
    # Content-security scanning is enrolled by the record's own after_commit hook.
    class BlobAttacher
      class Rejected < ArgumentError; end

      def initialize(root:, manifest:)
        @root = Pathname.new(root)
        @manifest = manifest
      end

      def call(record:, entry:)
        entry.files.each { |file| attach(record, file) }
      end

      private

      def attach(record, file)
        manifest_entry = @manifest.entry_for_blob(file['checksum'])
        raise Rejected, "#{file['filename']}: blob #{file['checksum']} is not in the manifest" unless manifest_entry
        unless manifest_entry.media_type == file['content_type']
          raise Rejected,
                "#{file['filename']}: content type #{file['content_type']} differs from manifest #{manifest_entry.media_type}"
        end

        path = @root.join(manifest_entry.path)
        raise Rejected, "#{file['filename']}: blob changed after verification" unless Manifest.sha256_of(path) == manifest_entry.sha256

        attachment = record.public_send(file['attachment'])
        return if attachment.attached? && attachment.blob.byte_size == manifest_entry.size && attachment.blob.checksum == md5_of(path)

        File.open(path, 'rb') do |io|
          attachment.attach(io:, filename: file['filename'], content_type: file['content_type'], identify: false)
        end
      end

      def md5_of(path)
        digest = Digest::MD5.new
        File.open(path, 'rb') { |io| while (chunk = io.read(Manifest::READ_CHUNK)) do digest.update(chunk) end }
        digest.base64digest
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
