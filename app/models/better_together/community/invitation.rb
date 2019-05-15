module BetterTogether
  module Community
    class Invitation < ApplicationRecord
      belongs_to  :invitable,
                  polymorphic: true
      belongs_to  :inviter,
                  polymorphic: true
      belongs_to  :invitee,
                  polymorphic: true
      belongs_to  :role,
                  optional: true

      enum status: {
        accepted: "accepted",
        declined: "declined",
        pending: "pending"
      }

      validates :bt_id,
                presence: true,
                uniqueness: true

      before_validation :generate_bt_id

      private

      def generate_bt_id
        return if self.bt_id.present?
        self.bt_id = loop do
          random_token = SecureRandom.uuid
          break random_token unless self.class.exists?(bt_id: random_token)
        end
      end
    end
  end
end
