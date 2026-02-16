# frozen_string_literal: true

# Rack 3.x renamed :unprocessable_entity to :unprocessable_content.
# JSONAPI::Resources 0.10.x still references :unprocessable_entity,
# causing validation error responses to have status 0 (nil.to_s).
# Restore the legacy symbol for backwards compatibility.
unless Rack::Utils::SYMBOL_TO_STATUS_CODE.key?(:unprocessable_entity)
  Rack::Utils::SYMBOL_TO_STATUS_CODE[:unprocessable_entity] = 422
end

JSONAPI.configure do |config|
  config.json_key_format = :underscored_key
  config.route_format = :underscored_route

  # Pagination: use paged paginator (page[number] / page[size])
  config.default_paginator = :paged
  config.default_page_size = 20
  config.maximum_page_size = 100

  config.top_level_meta_include_record_count = true
  config.top_level_meta_include_page_count = true
  # Don't add Pundit::NotAuthorizedError to whitelist - we handle it in ApplicationController
  config.exception_class_whitelist = []
end
