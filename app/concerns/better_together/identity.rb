
module BetterTogether
  module Identity
    extend ActiveSupport::Concern

    included do
      has_many :identifications,
               as: :identity
      has_many :agents,
               through: :identifications
    end

  end
end
