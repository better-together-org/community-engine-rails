module BetterTogether
  module Bt
    module Api
      class PasswordsController < Devise::PasswordsController
        respond_to :json

        # POST /resource/password
        def create
          @email = params[:email]

          @resource = resource_class.find_by(email: @email)
          self.resource = @resource

          resource.send_reset_password_instructions(
            email: @email,
            new_password_url: new_password_url
          )
          yield resource if block_given?

          if successfully_sent?(resource)
            respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
          else
            respond_with(resource)
          end
        end

        protected

        def resource_name
          :user
        end

        def after_resetting_password_path_for(resource); end

        def new_password_url
          params.fetch(
            :new_password_url,
            BetterTogether.default_user_new_password_url
          )
        end
      end
    end
  end
end
