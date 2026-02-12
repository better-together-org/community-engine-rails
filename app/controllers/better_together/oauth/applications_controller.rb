# frozen_string_literal: true

module BetterTogether
  module Oauth
    # Controller for managing OAuth applications
    # Allows users to register and manage applications that access the API
    class ApplicationsController < BetterTogether::ApplicationController
      before_action :authenticate_user!
      before_action :set_application, only: %i[show edit update destroy]

      # GET /oauth/applications
      def index
        @applications = current_user.person.oauth_applications.order(created_at: :desc)
      end

      # GET /oauth/applications/:id
      def show
        # Application is set by before_action
      end

      # GET /oauth/applications/new
      def new
        @application = current_user.person.oauth_applications.build(
          application_type: 'web',
          rate_limit_tier: 'free'
        )
      end

      # GET /oauth/applications/:id/edit
      def edit
        # Application is set by before_action
      end

      # POST /oauth/applications
      def create
        @application = current_user.person.oauth_applications.build(application_params)

        if @application.save
          flash[:success] = t('.success', name: @application.name)
          redirect_to oauth_application_path(@application)
        else
          render :new, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /oauth/applications/:id
      def update
        if @application.update(application_params)
          flash[:success] = t('.success', name: @application.name)
          redirect_to oauth_application_path(@application)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /oauth/applications/:id
      def destroy
        name = @application.name
        @application.destroy!
        flash[:success] = t('.success', name: name)
        redirect_to oauth_applications_path
      end

      private

      def set_application
        @application = current_user.person.oauth_applications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        flash[:error] = t('.not_found')
        redirect_to oauth_applications_path
      end

      def application_params
        params.require(:oauth_application).permit(
          :name,
          :redirect_uri,
          :scopes,
          :application_type,
          :confidential
        )
      end
    end
  end
end
