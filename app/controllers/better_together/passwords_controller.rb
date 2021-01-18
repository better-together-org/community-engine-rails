module BetterTogether
  class PasswordsController < Devise::PasswordsController
    respond_to :json

    protected

    def resource_name
      :user
    end
  end
end
