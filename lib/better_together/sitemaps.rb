# frozen_string_literal: true

require 'zlib'
require 'stringio'

module BetterTogether
  # Multi-platform XML sitemap generation.
  module Sitemaps
    module_function

    # Deterministic gzip (no mtime / OS byte in the header) so that re-generating
    # unchanged sitemap content produces byte-identical output and
    # BetterTogether::Sitemap#attach_file_if_changed? can skip the re-upload.
    def gzip(data)
      buffer = StringIO.new
      writer = Zlib::GzipWriter.new(buffer)
      writer.mtime = 0
      writer.write(data)
      writer.close
      bytes = buffer.string.b
      bytes.setbyte(9, 0xff) if bytes.bytesize > 9 # normalize the OS field
      bytes
    end

    # @param data [String] gzip-compressed bytes
    # @return [String] the decompressed content
    def gunzip(data)
      Zlib::GzipReader.new(StringIO.new(data)).read
    end
  end
end
