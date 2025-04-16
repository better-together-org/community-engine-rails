# frozen_string_literal: true

module BetterTogether
  # Calendar management and display
  class Calendar < ApplicationRecord
    include Creatable
    include FriendlySlug
    include Identifier
    include Privacy
    include Protected
    include Viewable

    belongs_to :community, class_name: '::BetterTogether::Community'

    slugged :name

    translates :name
    translates :description, backend: :action_text

    def to_s
      name
    end
  end
end
