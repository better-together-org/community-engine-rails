# frozen_string_literal: true

module BetterTogether
  # A Schedulable Event
  class Event < ApplicationRecord
    include Creatable
    include FriendlySlug
    include Identifier
    include Privacy
    include Viewable

    slugged :name

    translates :name
    translates :description, backend: :action_text

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        starts_at ends_at
      ]
    end

    def to_s
      name
    end
  end
end
