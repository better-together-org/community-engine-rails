# frozen_string_literal: true

module BetterTogether
  module Api
    module Oauth
      # Controller for managing OAuth applications via the API
      # Allows users to register and manage applications that access the API
      class ApplicationsController < BetterTogether::ApplicationController
        before_action :authenticate_user!
        before_action :set_application, only: %i[show update destroy]

        # GET /api/oauth_applications
        def index
          @applications = current_user.person.oauth_applications.order(created_at: :desc)

          respond_to do |format|
            format.json { render json: serialize_applications(@applications) }
          end
        end

        # GET /api/oauth_applications/:id
        def show
          respond_to do |format|
            format.json { render json: serialize_application(@application, include_secret: false) }
          end
        end

        # POST /api/oauth_applications
        def create
          @application = current_user.person.oauth_applications.build(application_params)

          if @application.save
            respond_to do |format|
              format.json do
                # Include secret only on creation (it cannot be retrieved later)
                render json: serialize_application(@application, include_secret: true),
                       status: :created
              end
            end
          else
            respond_to do |format|
              format.json { render json: { errors: @application.errors }, status: :unprocessable_entity }
            end
          end
        end

        # PATCH/PUT /api/oauth_applications/:id
        def update
          if @application.update(application_params)
            respond_to do |format|
              format.json { render json: serialize_application(@application, include_secret: false) }
            end
          else
            respond_to do |format|
              format.json { render json: { errors: @application.errors }, status: :unprocessable_entity }
            end
          end
        end

        # DELETE /api/oauth_applications/:id
        def destroy
          @application.destroy!

          respond_to do |format|
            format.json { head :no_content }
          end
        end

        private

        def set_application
          @application = current_user.person.oauth_applications.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          respond_to do |format|
            format.json do
              render json: { error: 'Application not found' }, status: :not_found
            end
          end
        end

        def application_params
          params.require(:oauth_application).permit(
            *BetterTogether::OauthApplication.permitted_attributes
          )
        end

        def serialize_application(app, include_secret: false)
          data = {
            id: app.id,
            name: app.name,
            uid: app.uid,
            redirect_uri: app.redirect_uri,
            scopes: app.scopes.to_s,
            confidential: app.confidential,
            created_at: app.created_at
          }
          data[:secret] = app.secret if include_secret
          { application: data }
        end

        def serialize_applications(apps)
          { applications: apps.map { |app| serialize_application(app)[:application] } }
        end
      end
    end
  end
end
