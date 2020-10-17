require "better_together/engine"

module BetterTogether
  mattr_accessor :user_class

  def self.user_class
    @@user_class.constantize
  end
end