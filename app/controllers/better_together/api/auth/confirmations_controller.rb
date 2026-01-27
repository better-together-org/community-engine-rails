# frozen_string_literal: true

module BetterTogether
  module Api
    module Auth
      # JSONAPI resource for user confirmations
      class ConfirmationsController < BetterTogether::Users::ConfirmationsController
        respond_to :json

        skip_before_action :check_platform_privacy, raise: false

        # POST /resource/confirmation
        def create
          self.resource = resource_class.send_confirmation_instructions(resource_params)

          yield resource if block_given?

          if successfully_sent?(resource)
            render json: {
              message: I18n.t('devise.confirmations.send_instructions')
            }, status: :ok
          else
            render json: {
              errors: resource.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        # GET /resource/confirmation?confirmation_token=abcdef
        def show
          self.resource = resource_class.confirm_by_token(params[:confirmation_token])
          yield resource if block_given?

          if resource.errors.empty?
            # Activate pending memberships after successful confirmation (matches parent behavior)
            activate_pending_memberships(resource)

            render json: {
              message: I18n.t('devise.confirmations.confirmed'),
              data: {
                type: 'users',
                id: resource.id,
                attributes: {
                  email: resource.email,
                  confirmed: true
                }
              }
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
      end
    end
  end
end
