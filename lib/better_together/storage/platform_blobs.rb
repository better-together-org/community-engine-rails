# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'

module BetterTogether
  module Storage
    # Export and removal of every blob stored on a platform's own storage service, for platform
    # export and deletion. Only blobs stamped with the platform's service are touched; blobs on the
    # shared default service are never listed here.
    class PlatformBlobs
      Result = Struct.new(:blob_count, :bytes, :skipped, keyword_init: true)

      def initialize(configuration)
        @configuration = configuration
      end

      def scope
        ActiveStorage::Blob.where(service_name: @configuration.storage_key)
      end

      # Streams each blob into dir/blobs/<sha256> and writes dir/MANIFEST.json. A blob whose object
      # is missing from the bucket is listed as skipped, not silently dropped.
      def export(dir)
        FileUtils.mkdir_p(File.join(dir, 'blobs'))
        files = []
        skipped = []
        scope.find_each { |blob| export_blob(blob, dir, files, skipped) }
        File.write(File.join(dir, 'MANIFEST.json'),
                   JSON.pretty_generate('schema' => '2.0', 'algorithm' => 'sha256', 'files' => files,
                                        'skipped' => skipped))
        Result.new(blob_count: files.size, bytes: files.sum { |f| f['size'] }, skipped: skipped)
      end

      # Deletes the objects and the blob rows. Dry run by default: reports what would go.
      def purge!(apply: false)
        count = scope.count
        bytes = scope.sum(:byte_size)
        scope.find_each(&:purge) if apply
        Result.new(blob_count: count, bytes: bytes, skipped: [])
      end

      private

      def export_blob(blob, dir, files, skipped)
        tmp = File.join(dir, 'blobs', ".#{blob.id}.part")
        sha = download_to(blob, tmp)
        final = File.join(dir, 'blobs', sha)
        FileUtils.mv(tmp, final)
        files << file_entry(blob, sha, final)
      rescue ActiveStorage::FileNotFoundError
        FileUtils.rm_f(tmp)
        skipped << { 'blob_id' => blob.id, 'reason' => 'missing_object' }
      end

      def download_to(blob, path)
        digest = Digest::SHA256.new
        File.open(path, 'wb') { |io| blob.download { |chunk| digest.update(chunk) && io.write(chunk) } }
        digest.hexdigest
      end

      def file_entry(blob, sha, path)
        { 'path' => "blobs/#{sha}", 'sha256' => sha, 'size' => File.size(path),
          'media_type' => blob.content_type, 'filename' => blob.filename.to_s }
      end
    end
  end
end
