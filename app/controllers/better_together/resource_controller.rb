# frozen_string_literal: true

module BetterTogether
  # Abstracts the retrieval of resources
  class ResourceController < ApplicationController # rubocop:todo Metrics/ClassLength
    before_action :set_resource_instance, only: %i[show edit update destroy]
    before_action :authorize_resource, only: %i[new show edit update destroy]
    before_action :resource_collection, only: %i[index]
    before_action :authorize_resource_class, only: %i[index]
    after_action :verify_authorized, except: :index

    helper_method :resource_class
    helper_method :resource_collection
    helper_method :resource_instance

    def index; end

    def show; end

    def new; end

    def edit; end

    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      resource_instance(resource_params)
      authorize_resource

      respond_to do |format|
        if @resource.save
          format.html do
            redirect_to url_for(@resource.becomes(resource_class)),
                        notice: "#{resource_class.model_name.human} was successfully created."
          end
          format.turbo_stream do
            flash.now[:notice] = "#{resource_class.model_name.human} was successfully created."
            redirect_to url_for(@resource.becomes(resource_class))
          end
        else
          format.turbo_stream do
            render status: :unprocessable_entity, turbo_stream: [
              turbo_stream.replace(helpers.dom_id(@resource, 'form'),
                                   partial: 'form',
                                   locals: { resource_name.to_sym => @resource }),
              turbo_stream.update('form_errors',
                                  partial: 'layouts/better_together/errors',
                                  locals: { object: @resource })
            ]
          end
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end

    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize_resource

      respond_to do |format| # rubocop:todo Metrics/BlockLength
        if @resource.update(resource_params)
          format.html do
            redirect_to url_for([:edit, @resource.becomes(resource_class)]),
                        notice: "#{resource_class.model_name.human} was successfully updated."
          end
          format.turbo_stream do
            flash.now[:notice] = "#{resource_class.model_name.human} was successfully updated."
            render turbo_stream: [
              turbo_stream.replace(helpers.dom_id(@resource, 'form'),
                                   partial: 'form',
                                   locals: { resource_name.to_sym => @resource }),
              turbo_stream.replace('flash_messages',
                                   partial: 'layouts/better_together/flash_messages',
                                   locals: { flash: })
            ]
          end
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            render status: :unprocessable_entity, turbo_stream: [
              turbo_stream.replace(helpers.dom_id(@resource, 'form'),
                                   partial: 'form',
                                   locals: { resource_name.to_sym => @resource }),
              turbo_stream.update('form_errors',
                                  partial: 'layouts/better_together/errors',
                                  locals: { object: @resource })
            ]
          end
        end
      end
    end

    def destroy
      authorize_resource

      resource_string = resource_instance.to_s

      if resource_instance.destroy
        redirect_to url_for(resource_class),
                    notice: "#{resource_class.model_name.human} #{resource_string} was successfully removed."
      else
        render :show, status: :unprocessable_entity
      end
    end

    protected

    def authorize_resource
      authorize resource_instance
    rescue Pundit::NotAuthorizedError
      render_not_found and return
    end

    def authorize_resource_class
      authorize resource_class
    rescue Pundit::NotAuthorizedError
      render_not_found and return
    end

    def id_param
      @id_param ||= params[:id]
    end

    def resource_class
      raise 'You must set a resource class in your controller by overriding the resource_class method.'
    end

    def resource_collection
      @resources ||= policy_scope(resource_class)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end

    def resource_instance(attrs = {})
      @resource ||= resource_class.new(attrs)

      instance_variable_set("@#{resource_name}", @resource)
    end

    def resource_instance_collection
      resource_collection
    end

    def resource_name(plural: false)
      name = resource_class.model_name.param_key
      name = name.pluralize if plural

      name.underscore
    end

    def param_name
      resource_name.to_sym
    end

    def resource_params
      params.require(param_name).permit(permitted_attributes)
    rescue ActionController::ParameterMissing
      # treat missing params as empty attributes so validations fire normally
      {}.with_indifferent_access
    end

    def set_resource_instance
      @resource = resource_instance_collection.find(id_param)
      instance_variable_set("@#{resource_name}", @resource)
    end

    def permitted_attributes
      resource_class.permitted_attributes
    end
  end
end
