module BetterTogether
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json
    before_action :configure_permitted_parameters

    def create
      build_resource(sign_up_params)

      # give confirmation value from params priority
      @confirmation_url = params.fetch(
        :confirmation_url,
        BetterTogether.default_user_confirmation_url
      )

      # success confirmation url is required
      if confirmable_enabled? && !@confirmation_url
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
            confirmation_url: @confirmation_url
          })
        end

        if resource.active_for_authentication?
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
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

    def configure_permitted_parameters
      # for user account creation i.e sign up
      devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation, { person_attributes: [ :name, :description] }])
    end

    def confirmable_enabled?
      resource_class.devise_modules.include?(:confirmable)
    end

    def after_inactive_sign_up_path_for(resource); end
  end
end
