module BetterTogether
  class RegistrationsController < Devise::RegistrationsController
    # before_action :configure_permitted_parameters
    respond_to :json

    protected

    # def resource_name
    #   :user
    # end
  end
end
