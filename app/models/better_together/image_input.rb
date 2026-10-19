# frozen_string_literal: true

module BetterTogether
  # Decodes a base64 image sent through the API (the JSON:API cannot upload files). The type comes from the bytes,
  # never from the client; each model keeps its own attachment validators on top.
  module ImageInput
    MAX_BYTES = 5.megabytes
    ALLOWED_TYPES = { 'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp' }.freeze

    Result = Struct.new(:bytes, :type, :error)

    module_function

    def decode(data, max_bytes: MAX_BYTES)
      bytes = Base64.strict_decode64(data)
      return Result.new(nil, nil, "is too large (limit #{max_bytes / 1.megabyte} MB)") if bytes.bytesize > max_bytes

      type = Marcel::MimeType.for(StringIO.new(bytes))
      return Result.new(nil, nil, 'must be a JPEG, PNG or WebP image') unless ALLOWED_TYPES.key?(type)

      Result.new(bytes, type, nil)
    rescue ArgumentError
      Result.new(nil, nil, 'is not valid base64')
    end

    def filename(name, type, default)
      safe = File.basename(name.to_s).gsub(/[^\w.-]/, '_').first(100)
      safe.presence || "#{default}.#{ALLOWED_TYPES[type]}"
    end
  end
end
