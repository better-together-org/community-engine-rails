
module BetterTogether
  module Community
    module BetterTogetherId
      extend ActiveSupport::Concern

      included do
        # validates :bt_id,
        #         presence: true,
        #         uniqueness: true

        before_create :generate_bt_id

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
end
