module BetterTogether
  class ConfirmationsController < Devise::ConfirmationsController
    respond_to :json

    # GET /resource/confirmation?confirmation_token=abcdef
    def show
      self.resource = resource_class.confirm_by_token(params[:confirmation_token])

      if resource.errors.empty?
        yield resource if block_given?
        
        redirect_to redirect_url
      else
        respond_with_navigational(resource.errors, status: :unprocessable_entity){ render :new }
      end
    end

    protected

    def resource_name
      :user
    end

     # give redirect value from params priority or fall back to default value if provided
    def redirect_url
      params.fetch(
        :redirect_url,
        BetterTogether.default_user_confirm_success_url
      )
    end

    def after_confirmation_path_for(resource_name, resource); end
  end
end
