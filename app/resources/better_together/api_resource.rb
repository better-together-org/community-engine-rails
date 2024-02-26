# frozen_string_literal: true

# require_dependency 'jsonapi/resource'

module BetterTogether
  # Base JSONAPI serializer that sets common attrbutes
  class ApiResource < ::JSONAPI::Resource
    abstract
    include Pundit::Resource

    attributes :created_at, :updated_at
  end
end
