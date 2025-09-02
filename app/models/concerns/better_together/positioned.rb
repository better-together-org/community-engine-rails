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

    class_methods do
      def extra_permitted_attributes
        super + %i[position]
      end
    end

    def position
      read_attribute(:position) || set_position
    end

    def position_scope
      # Override in models where scoping by a column is needed
      nil
    end

    def set_position # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      return if read_attribute(:position).present? # Ensure we don't override an existing position

      max_position = if position_scope.present?
                       # position_scope may be a single column (Symbol) or an Array of columns.
                       cols = Array(position_scope)

                       # Build a where clause mapping each scope column to its normalized value
                       conditions = cols.each_with_object({}) do |col, memo|
                         value = self[col]
                         value = value.presence if value.respond_to?(:presence)
                         memo[col] = value
                       end

                       self.class.where(conditions).maximum(:position)
                     else
                       self.class.maximum(:position)
                     end

      self.position = max_position ? max_position + 1 : 0
    end
  end
end
