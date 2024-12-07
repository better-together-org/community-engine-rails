# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources
  class ResourceController < ApplicationController
    before_action :set_resource_instance, only: %i[show edit update destroy]
    before_action :authorize_resource, only: %i[show edit update destroy]
    before_action :authorize_resource_class, only: %i[index]
    after_action :verify_authorized, except: :index

    helper_method :resource_class
    helper_method :resource_collection
    helper_method :resource_instance

    protected

    def authorize_resource
      authorize resource_instance
    end

    def authorize_resource_class
      authorize resource_class
    end

    def id_param
      @id_param ||= params[:id]
    end

    def resource_class
      raise 'You must set a resource class in your controller by overriding the resource_class method.'
    end

    def resource_collection
      resource_class
    end

    def resource_instance
      @resource
    end

    def set_resource_instance
      @resource = resource_collection.find(id_param)
    end
  end
end
