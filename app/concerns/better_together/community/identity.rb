
module BetterTogether
  module Community
    module Identity
      extend ActiveSupport::Concern

      included do
        has_many :identifications,
                 as: :identity
      end

    end
  end
end
