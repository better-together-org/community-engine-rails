# frozen_string_literal: true

module BetterTogether
  module Community
    # Generates a unique identifier for any class that includes this module
    module BetterTogetherId
      extend ActiveSupport::Concern

      included do
        # validates :bt_id,
        #         presence: true,
        #         uniqueness: true

        before_create :generate_bt_id

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
end
