# frozen_string_literal: true

module BetterTogether
  # Join an event to its host
  class EventHost < ApplicationRecord
    include PlatformScoped

    belongs_to :event, class_name: 'BetterTogether::Event'
    belongs_to :host, polymorphic: true, required: true

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        host_id host_type event_id
      ]
    end
  end
end
