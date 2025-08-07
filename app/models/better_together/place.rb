# frozen_string_literal: true

module BetterTogether
  # The Place class represents a location within the BetterTogether application.
  # It includes modules for creatable, identifier, and privacy functionalities.
  # A Place belongs to a Community and a Space, with the Community association being optional.
  class Place < ApplicationRecord
    include Creatable
    include Identifier
    include Privacy

    belongs_to :community, class_name: 'BetterTogether::Community', optional: true
    belongs_to :space, class_name: 'BetterTogether::Geography::Space'
  end
end
