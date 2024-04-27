# frozen_string_literal: true

module BetterTogether
  # Generates a unique identifier for any class that includes this module
  module BetterTogetherId
    extend ActiveSupport::Concern

    included do
      self.implicit_order_column = :created_at

      before_validation :generate_id

      private

      def generate_id
        return if id.present?

        self.id = loop do
          random_token = SecureRandom.uuid
          break random_token unless self.class.exists?(id: random_token)
        end
      end
    end
  end
end
