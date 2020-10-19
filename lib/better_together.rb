require "better_together/engine"

module BetterTogether
  mattr_accessor :user_class

  class << self
    attr_reader :config

    def configure
      @config = Configuration.new
      yield config
    end

    def user_class
      @@user_class.constantize
    end
  end
end