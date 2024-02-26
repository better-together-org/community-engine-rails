# frozen_string_literal: true

# app/builders/better_together/builder.rb

module BetterTogether
  # Base builder to automate creation of important built-in data types
  class Builder

    class << self
      def build(clear: false)
        clear_existing if clear
        seed_data
      end

      def seed_data
        raise 'seed_data should be implemented in your child class'
      end

      # Clear existing data - Use with caution!
      def clear_existing
        raise 'clear_existing should be implemented in your child class'
      end
    end
  end
end
