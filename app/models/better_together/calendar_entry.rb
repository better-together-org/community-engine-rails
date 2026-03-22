# frozen_string_literal: true

module BetterTogether
  # Join model between Calendar and Event for future calendar organization
  class CalendarEntry < ApplicationRecord
    belongs_to :calendar, class_name: 'BetterTogether::Calendar'
    belongs_to :event, class_name: 'BetterTogether::Event'

    validates :event_id, uniqueness: { scope: :calendar_id }
  end
end
