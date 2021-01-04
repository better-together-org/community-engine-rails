module BetterTogether
  class ConfirmationsController < Devise::ConfirmationsController
    respond_to :json

    protected

    def resource_name
      :user
    end
  end
end
