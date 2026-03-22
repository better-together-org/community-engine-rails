# frozen_string_literal: true

module BetterTogether
  # Provides backward compatibility between 'timezone' and 'time_zone' attribute naming conventions.
  #
  # This concern ensures models respond to both `timezone` and `time_zone` accessors regardless
  # of which naming convention the underlying storage uses. This is useful during migration from
  # the underscore convention (time_zone) to the non-underscore convention (timezone).
  #
  # Uses method_missing for maximum flexibility - works regardless of when attributes are defined
  # (including late-bound definitions via store_attributes).
  #
  # @example Including in a model with 'timezone' column
  #   class Event < ApplicationRecord
  #     include TimezoneAttributeAliasing
  #     # Now responds to both event.timezone and event.time_zone
  #   end
  #
  # @example Including in a model with 'time_zone' column
  #   class Platform < ApplicationRecord
  #     include TimezoneAttributeAliasing
  #     # Now responds to both platform.time_zone and platform.timezone
  #   end
  #
  # @example Including in a model with store_attributes (any order)
  #   class Person < ApplicationRecord
  #     include TimezoneAttributeAliasing  # Can be included before or after
  #     store_attributes :preferences do
  #       time_zone String
  #     end
  #     # Now responds to both person.time_zone and person.timezone
  #   end
  #
  module TimezoneAttributeAliasing
    extend ActiveSupport::Concern

    # Handle missing timezone/time_zone methods by delegating to the other
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Lint/CopDirectiveSyntax
    def method_missing(method_name, *args, &) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
      # rubocop:enable Lint/CopDirectiveSyntax
      case method_name
      when :timezone
        # If timezone is called but doesn't exist, try time_zone
        return super unless respond_to?(:time_zone, true)

        time_zone
      when :timezone=
        # If timezone= is called but doesn't exist, try time_zone=
        return super unless respond_to?(:time_zone=, true)

        self.time_zone = args.first
      when :time_zone
        # If time_zone is called but doesn't exist, try timezone
        return super unless respond_to?(:timezone, true)

        timezone
      when :time_zone=
        # If time_zone= is called but doesn't exist, try timezone=
        return super unless respond_to?(:timezone=, true)

        self.timezone = args.first
      else
        super
      end
    end
    # rubocop:enable Metrics/MethodLength

    # Support proper introspection for timezone/time_zone methods
    def respond_to_missing?(method_name, include_private = false)
      case method_name
      when :timezone, :timezone=
        # Respond to timezone if time_zone exists
        respond_to?(:time_zone, include_private) || super
      when :time_zone, :time_zone=
        # Respond to time_zone if timezone exists
        respond_to?(:timezone, include_private) || super
      else
        super
      end
    end
  end
end
