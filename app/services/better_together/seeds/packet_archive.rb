# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

require 'rubygems/package'
require 'zlib'

module BetterTogether
  module Seeds
    # Safely unpacks a .tar.gz packet into an empty directory. Only regular files and
    # directories under the packet layout are written; links, absolute paths, traversal and
    # oversized archives are rejected before anything is extracted past the offending entry.
    module PacketArchive
      class Rejected < SecurityError; end

      MAX_ENTRIES = 20_000
      ALLOWED = %r{\A(packet\.yml|MANIFEST\.json(\.sig|\.asc)?|records/[A-Za-z0-9_./-]+\.yml|blobs/[0-9a-f]{64})\z}
      COPY_CHUNK = 1.megabyte

      module_function

      def extract(archive_path, destination, max_bytes: BlobPolicy.max_archive_bytes)
        dest = Pathname.new(destination).expand_path
        raise Rejected, 'destination must be an empty directory' if dest.exist? && dest.children.any?

        FileUtils.mkdir_p(dest)
        total = 0
        count = 0
        Zlib::GzipReader.open(archive_path.to_s) do |gz|
          Gem::Package::TarReader.new(gz).each do |entry|
            count += 1
            raise Rejected, "archive has more than #{MAX_ENTRIES} entries" if count > MAX_ENTRIES

            total += write_entry(entry, dest, max_bytes - total)
          end
        end
        dest
      end

      def write_entry(entry, dest, remaining)
        name = entry.full_name.delete_prefix('./')
        return 0 if entry.directory?
        raise Rejected, "#{name}: only regular files are allowed" unless entry.file?
        raise Rejected, "#{name}: not part of the packet layout" unless ALLOWED.match?(name)

        target = dest.join(name)
        FileUtils.mkdir_p(target.dirname)
        written = 0
        File.open(target, 'wb') do |out|
          while (chunk = entry.read(COPY_CHUNK))
            written += chunk.bytesize
            raise Rejected, 'archive exceeds the allowed size' if written > remaining

            out.write(chunk)
          end
        end
        written
      end

      private_class_method :write_entry
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
