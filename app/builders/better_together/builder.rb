# frozen_string_literal: true

# app/builders/better_together/builder.rb

module BetterTogether
  # Base builder to automate creation of important built-in data types
  class Builder
    class << self
      def build(clear: false)
        if clear
          ActiveRecord::Base.transaction do
            clear_existing
          end
        end
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
