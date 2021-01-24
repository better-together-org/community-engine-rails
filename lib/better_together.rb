require "better_together/engine"

module BetterTogether
  mattr_accessor :user_class,
                 :default_user_confirm_success_url,
                 :default_user_new_password_url

  class << self
    def user_class
      @@user_class.constantize
    end
  end
end