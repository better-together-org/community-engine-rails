# frozen_string_literal: true

module BetterTogether
  # Allows ordering by position column
  module Positioned
    extend ActiveSupport::Concern

    included do
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      before_validation :set_position, unless: -> { read_attribute(:position).present? }

      scope :positioned, -> { order(:position) }
    end

    def position
      read_attribute(:position) || set_position
    end

    def position_scope
      # Override in models where scoping by a column is needed
      nil
    end

    def set_position
      return if read_attribute(:position).present? # Ensure we don't override an existing position

      max_position = if position_scope.present?
                       self.class.where(position_scope => self[position_scope]).maximum(:position)
                     else
                       self.class.maximum(:position)
                     end

      self.position = max_position ? max_position + 1 : 0
    end
  end
end
