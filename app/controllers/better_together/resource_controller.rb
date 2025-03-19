# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources
  class ResourceController < ApplicationController
    before_action :set_resource_instance, only: %i[show edit update destroy]
    before_action :authorize_resource, only: %i[new show edit update destroy]
    before_action :resource_collection, only: %i[index]
    before_action :authorize_resource_class, only: %i[index]
    after_action :verify_authorized, except: :index

    helper_method :resource_class
    helper_method :resource_collection
    helper_method :resource_instance

    def index
    end

    def show
    end

    def create
      resource_instance(resource_params)
      authorize_resource

      if @resource.save
        redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      resource_instance(resource_params)
      authorize_resource

      if @resource.save
        redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

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
      @resources ||= policy_scope(resource_class)

      self.instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end

    def resource_instance(params = {})
      @resource ||= resource_class.new(params)

      self.instance_variable_set("@#{resource_name}", @resource)
    end

    def resource_name(plural: false)
      name = resource_class.name.demodulize
      name = name.pluralize if plural

      name.underscore
    end

    def resource_params
      params.require(resource_name.to_sym).permit(permitted_attributes)
    end

    def set_resource_instance
      @resource = resource_collection.find(id_param)
    end

    def permitted_attributes
      resource_class.extra_permitted_attributes
    end
  end
end
