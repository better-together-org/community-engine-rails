require_dependency 'jsonapi/resource_controller'

module BetterTogether
  class ApiController < ::JSONAPI::ResourceController
    include Pundit::Authorization
    include Pundit::ResourceController
    protect_from_forgery with: :null_session
  end
end
