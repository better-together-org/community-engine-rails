module BetterTogether
  module Community
    module Agent
    extend ActiveSupport::Concern

      included do
        has_many :identifications,
                 as: :agent
        has_many :identities,
             through: :identifications

        def active_identity
          identification = identifications.find_by(active: true) || identifications.first

          return if !identification

          identification.identity
        end
      end
    end
  end
end
