# frozen_string_literal: true

module BetterTogether
  # Base API controller
  class ApiController < ::JSONAPI::ResourceController
    include Pundit::Authorization
    include Pundit::ResourceController

    protect_from_forgery with: :exception, unless: -> { request.format.json? }
  end
end
