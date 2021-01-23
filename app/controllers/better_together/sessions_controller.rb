module BetterTogether
  class SessionsController < Devise::SessionsController
    respond_to :json

    protected

    def respond_with(resource, _opts = {})
      render json: resource
    end

    def respond_to_on_destroy
      head :ok
    end

    def after_sign_in_path_for(resource); end
  end
end
