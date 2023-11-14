module BetterTogether
  module Bt
    module Api
      class ConfirmationsController < Devise::ConfirmationsController
        respond_to :json

        # POST /resource/confirmation
        def create
          @email = params[:user][:email]

          @resource = resource_class.find_by(email: @email)
          @resource.send_confirmation_instructions({
            confirmation_url: confirmation_url
          }) if @resource

          self.resource = @resource || resource_class.send_confirmation_instructions(resource_params)

          yield resource if block_given?

          if successfully_sent?(resource)
            respond_with({}, location: after_resending_confirmation_instructions_path_for(resource_name))
          else
            respond_with(resource)
          end
        end

        protected

        def resource_name
          :user
        end

        # give redirect value from params priority or fall back to default value if provided
        def confirmation_url
          params.fetch(
            :confirmation_url,
            BetterTogether.default_user_confirmation_url
          )
        end

        def after_confirmation_path_for(resource_name, resource); end
      end
    end
  end
end
