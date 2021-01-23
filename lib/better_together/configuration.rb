module BetterTogether
  class Configuration
    attr_reader :user_class, :default_user_confirm_success_url

    def user_class=(class_as_string)
      BetterTogether.user_class = class_as_string
    end

    def default_user_confirm_success_url=(url)
      BetterTogether.default_user_confirm_success_url = url
    end
  end
end
