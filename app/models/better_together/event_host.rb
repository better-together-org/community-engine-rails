# frozen_string_literal: true

module BetterTogether
  class EventHost < ApplicationRecord
    belongs_to :event, class_name: 'BetterTogether::Event'
    belongs_to :host, polymorphic: true
  end
end
