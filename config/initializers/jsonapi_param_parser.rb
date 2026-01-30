# frozen_string_literal: true

# Register parameter parser for JSON API MIME type
# This tells Rails/ActionDispatch how to parse request bodies with application/vnd.api+json Content-Type
Rails.application.config.to_prepare do
  # Register the parameter parser for JSONAPI MIME type if not already registered
  jsonapi_mime_type = Mime::Type.lookup_by_extension(:jsonapi)

  if jsonapi_mime_type && !ActionDispatch::Request.parameter_parsers.key?(jsonapi_mime_type.symbol)
    ActionDispatch::Request.parameter_parsers[:jsonapi] = lambda do |body|
      JSON.parse(body)
    end
  end
end
