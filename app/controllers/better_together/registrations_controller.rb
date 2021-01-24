module BetterTogether
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json

    def create
      build_resource(sign_up_params)

      # give redirect value from params priority
      @redirect_url = params.fetch(
        :confirm_success_url,
        BetterTogether.default_user_confirm_success_url
      )

      # success redirect url is required
      if confirmable_enabled? && !@redirect_url
        return render json: { error: 'You must configure a default user confirmation success url' }.to_json
      end

      # override email confirmation, must be sent manually from ctrl
      callback_name = defined?(ActiveRecord) && resource_class < ActiveRecord::Base ? :commit : :create
      resource_class.set_callback(callback_name, :after, :send_on_create_confirmation_instructions)
      resource_class.skip_callback(callback_name, :after, :send_on_create_confirmation_instructions)

      if resource.respond_to? :skip_confirmation_notification!
        # Fix duplicate e-mails by disabling Devise confirmation e-mail
        resource.skip_confirmation_notification!
      end

      resource.save
      yield resource if block_given?
      if resource.persisted?
        unless resource.confirmed?
          # user will require email authentication
          resource.send_confirmation_instructions({
            redirect_url: @redirect_url
          })
        end

        if resource.active_for_authentication?
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message! :
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end

    protected

    def after_inactive_sign_up_path_for(resource); end
  end
end
