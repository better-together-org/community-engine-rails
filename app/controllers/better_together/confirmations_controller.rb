module BetterTogether
  class ConfirmationsController < Devise::ConfirmationsController
    respond_to :json

    protected

    def resource_name
      :user
    end

    def after_confirmation_path_for(resource_name, resource)
      if signed_in?(resource_name)
        signed_in_root_path(resource)
      else
        better_together.new_session_path(resource_name)
      end
    end
  end
end
