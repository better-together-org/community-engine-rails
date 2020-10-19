module BetterTogether
  class Configuration
    attr_reader :user_class

    def user_class=(class_as_string)
      BetterTogether.user_class = class_as_string
    end
  end
end
