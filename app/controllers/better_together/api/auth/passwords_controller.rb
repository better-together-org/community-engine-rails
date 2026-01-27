# frozen_string_literal: true

module BetterTogether
  module Api
    module Auth
      # JSONAPI resource for user passwords
      class PasswordsController < BetterTogether::Users::PasswordsController
        respond_to :json

        skip_before_action :check_platform_privacy, raise: false

        # POST /resource/password
        def create
          self.resource = resource_class.send_reset_password_instructions(resource_params)

          yield resource if block_given?

          if successfully_sent?(resource)
            render json: {
              message: I18n.t('devise.passwords.send_instructions')
            }, status: :ok
          else
            render json: {
              errors: resource.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        protected

        def resource_name
          :user
        end

        def after_resetting_password_path_for(resource); end
      end
    end
  end
end
