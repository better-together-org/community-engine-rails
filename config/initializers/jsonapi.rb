# frozen_string_literal: true

JSONAPI.configure do |config|
  config.json_key_format = :underscored_key
  config.route_format = :underscored_route
  config.top_level_meta_include_record_count = true
  config.top_level_meta_include_page_count = true
  # Don't add Pundit::NotAuthorizedError to whitelist - we handle it in ApplicationController
  config.exception_class_whitelist = []
end
