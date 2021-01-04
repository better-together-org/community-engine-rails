module BetterTogether
  module Bt
    module Api
      module V1
        class PasswordsController < Devise::PasswordsController
          respond_to :json

          protected

          def resource_name
            :user
          end
        end
      end
    end
  end
end
