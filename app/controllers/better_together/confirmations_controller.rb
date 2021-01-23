module BetterTogether
  class ConfirmationsController < Devise::ConfirmationsController
    respond_to :json

    protected

    def resource_name
      :user
    end

    def after_confirmation_path_for(resource_name, resource)
      
    end
  end
end
