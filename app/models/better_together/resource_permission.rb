module BetterTogether
  class ResourcePermission < ApplicationRecord
    ACTIONS = %w[create read update delete list manage view].freeze
    
    RESOURCE_CLASSES = [
      'BetterTogether::Community',
      'BetterTogether::Platform'
    ].freeze

    include Identifier
    include Positioned
    include Protected

    slugged :identifier, dependent: :delete_all

    validates :action, inclusion: { in: ACTIONS }
    validates :position, uniqueness: { scope: :resource_type }
    validates :resource_type, inclusion: { in: RESOURCE_CLASSES }

    scope :positioned, -> { order(:resource_type, :position) }

    def position_scope
      :resource_type
    end

    def to_s
      identifier
    end
  end
end
