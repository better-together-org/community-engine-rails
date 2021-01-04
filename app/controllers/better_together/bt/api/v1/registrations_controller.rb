module BetterTogether
  module Bt
    module Api
      module V1
        class RegistrationsController < Devise::RegistrationsController
          # before_action :configure_permitted_parameters
          respond_to :json

          protected

          def resource_name
            :user
          end

          #  def configure_permitted_parameters
          #   devise_parameter_sanitizer.permit(
          #     :sign_up,
          #     keys: %i[
          #       email password password_confirmation
          #     ]
          #   )
          # end
        end
      end
    end
  end
end
