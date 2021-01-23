module BetterTogether
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json

    protected

    def after_inactive_sign_up_path_for(resource); end
  end
end
