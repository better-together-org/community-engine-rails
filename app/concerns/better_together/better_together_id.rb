# frozen_string_literal: true

module BetterTogether
  # Generates a unique identifier for any class that includes this module
  module BetterTogetherId
    extend ActiveSupport::Concern

    included do
      self.primary_key = :bt_id
      self.implicit_order_column = :created_at

      validates :bt_id,
                presence: true,
                uniqueness: true

      before_validation :generate_bt_id

      def id
        bt_id
      end

      def id=(arg)
        bt_id = arg
      end

      private

      def generate_bt_id
        return if bt_id.present?

        self.bt_id = loop do
          random_token = SecureRandom.uuid
          break random_token unless self.class.exists?(bt_id: random_token)
        end
      end
    end
  end
end
