# frozen_string_literal: true

require 'better_together/engine'

# Convenience setters and getters for the engine
module BetterTogether
  mattr_accessor :base_url,
                 :new_user_password_path,
                 :user_class,
                 :user_confirmation_path

  class << self
    def base_path_with_locale(locale: I18n.locale)
      "#{BetterTogether::Engine.routes.find_script_name({})}#{locale}"
    end

    def base_url_with_locale(locale: I18n.locale)
      "#{base_url}/#{locale}"
    end

    def new_user_password_url
      base_url + new_user_password_path
    end

    def new_user_password_path
      return @@new_user_password_path if @@new_user_password_path.present?

      ::BetterTogether::Engine.routes.url_helpers.new_user_password_path
    end

    def user_class
      @@user_class.constantize
    end

    def user_confirmation_path
      return @@user_confirmation_path if @@user_confirmation_path.present?

      ::BetterTogether::Engine.routes.url_helpers.user_confirmation_path
    end

    def user_confirmation_url
      base_url + user_confirmation_path
    end
  end
end
