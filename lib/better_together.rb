require "better_together/engine"

module BetterTogether
  mattr_accessor :user_class

  class << self
    def user_class
      @@user_class.constantize
    end
  end
end