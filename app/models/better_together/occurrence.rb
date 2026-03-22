# frozen_string_literal: true

module BetterTogether
  # Value object representing a single occurrence of a recurring schedulable resource
  # Delegates most attributes to the parent resource but calculates specific occurrence times
  class Occurrence
    attr_reader :parent, :starts_at

    # @param parent [ActiveRecord::Base] The recurring parent resource (Event, Task, etc.)
    # @param starts_at [Time] The specific start time for this occurrence
    def initialize(parent, starts_at)
      @parent = parent
      @starts_at = starts_at
    end

    # Calculate end time for this occurrence based on parent's duration
    # @return [Time, nil]
    def ends_at
      return nil unless parent.respond_to?(:duration_minutes) && parent.duration_minutes.present?

      starts_at + parent.duration_minutes.minutes
    end

    # Delegate all other methods to the parent resource
    # This allows occurrences to act like the parent for name, description, etc.
    def method_missing(method_name, *, &)
      if parent.respond_to?(method_name)
        parent.public_send(method_name, *, &)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      parent.respond_to?(method_name, include_private) || super
    end

    # Get the date of this occurrence
    # @return [Date]
    def date
      starts_at.to_date
    end

    # Check if this occurrence is on a specific date
    # @param date [Date] Date to check
    # @return [Boolean]
    def on_date?(date)
      starts_at.to_date == date
    end

    # Check if this occurrence is in the past
    # @return [Boolean]
    def past?
      starts_at < Time.current
    end

    # Check if this occurrence is in the future
    # @return [Boolean]
    def future?
      starts_at > Time.current
    end

    # Check if this occurrence is today
    # @return [Boolean]
    def today?
      starts_at.to_date == Time.current.to_date
    end

    # Convert to a hash representation
    # @return [Hash]
    def to_h
      {
        starts_at: starts_at,
        ends_at: ends_at,
        parent_id: parent.id,
        parent_type: parent.class.name
      }
    end

    # String representation
    # @return [String]
    def to_s
      "#{parent.class.name} occurrence at #{starts_at}"
    end

    # Equality comparison
    # @param other [Occurrence] Other occurrence to compare
    # @return [Boolean]
    def ==(other)
      other.is_a?(Occurrence) &&
        other.parent == parent &&
        other.starts_at == starts_at
    end
    alias eql? ==

    # Hash code for hash-based collections
    # @return [Integer]
    def hash
      [parent, starts_at].hash
    end
  end
end
