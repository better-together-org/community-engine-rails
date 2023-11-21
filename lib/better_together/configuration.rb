module BetterTogether
  class Configuration
    attr_reader :base_url,
                :new_user_password_path,
                :user_class,
                :user_confirmation_path

    def base_url=(url)
      BetterTogether.base_url = url
    end

    def new_user_password_path=(path)
      BetterTogether.new_user_password_path = path
    end

    def user_class=(class_as_string)
      BetterTogether.user_class = class_as_string
    end

    def user_confirmation_path=(path)
      BetterTogether.user_confirmation_path = path
    end
  end
end
