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

    has_many :calendar_entries, class_name: 'BetterTogether::CalendarEntry', dependent: :destroy
    has_many :events, through: :calendar_entries

    slugged :name

    translates :name
    translates :description, backend: :action_text

    def to_s
      name
    end
  end
end
