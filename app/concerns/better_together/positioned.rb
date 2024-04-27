# frozen_string_literal: true

module BetterTogether
  # Allows ordering by position column
  module Positioned
    extend ActiveSupport::Concern

    included do
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      before_validation do
        throw(:abort) unless position.present?
        set_position
      end

      scope :positioned, -> { order(:position) }
    end

    def position
      return read_attribute(:position) if persisted? || read_attribute(:position).present?

      set_position
    end

    def position_scope
      nil
    end

    def set_position
      max_position = self.class.maximum(:position)

      if position_scope.present?
        max_position = max_position.where(
          position_scope => self[position_scope]
        )
      end

      self.position = max_position ? max_position + 1 : 0
    end
  end
end
