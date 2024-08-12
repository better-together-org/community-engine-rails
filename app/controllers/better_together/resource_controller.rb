# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources
  class ResourceController < ApplicationController
    protected

    def id_param
      @id_param ||= params[:id]
    end

    def resource_class
      raise 'You must set a resource class in your controller by overriding the resource_class method.'
    end

    def resource_collection
      resource_class
    end

    def set_resource_instance
      @resource = resource_collection.find(id_param)
    end
  end
end
