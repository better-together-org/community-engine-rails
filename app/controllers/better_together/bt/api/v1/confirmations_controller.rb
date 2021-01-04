module BetterTogether
  module Bt
    module Api
      module V1
        class ConfirmationsController < Devise::ConfirmationsController
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
