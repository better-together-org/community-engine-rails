# frozen_string_literal: true

module BetterTogether
  module Bt
    module Api
      # JSONAPI resource for user passwords
      class PasswordsController < Devise::PasswordsController
        respond_to :json

        # POST /resource/password
        # rubocop:todo Metrics/MethodLength
        def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          @email = params[:email]

          @resource = resource_class.find_by(email: @email)
          self.resource = @resource

          resource.send_reset_password_instructions(
            email: @email,
            new_password_url:
          )
          yield resource if block_given?

          if successfully_sent?(resource)
            respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
          else
            respond_with(resource)
          end
        end
        # rubocop:enable Metrics/MethodLength

        protected

        def resource_name
          :user
        end

        def after_resetting_password_path_for(resource); end

        def new_password_url
          params.fetch(
            :new_password_url,
            BetterTogether.default_new_user_password_url
          )
        end
      end
    end
  end
end
