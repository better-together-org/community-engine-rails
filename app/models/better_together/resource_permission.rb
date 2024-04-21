module BetterTogether
  class ResourcePermission < ApplicationRecord
    RESOURCE_CLASSES = [
      '::BetterTogether::Platform'
    ].freeze

    include Identifier
    include Positioned
    include Protected

    slugged :identifier, dependent: :delete_all

    validates :resource_class, inclusion: { in: RESOURCE_CLASSES }

    def to_s
      identifier
    end
  end
end
