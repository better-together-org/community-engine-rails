# frozen_string_literal: true

module BetterTogether
  class EventHost < ApplicationRecord
    belongs_to :event, class_name: 'BetterTogether::Event'
    belongs_to :host, polymorphic: true

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        host_id host_type event_id
      ]
    end
  end
end
