# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Attribute values a packet cannot know in advance. `$now` becomes the time of the plant when the record
    # is created; it is never rewritten on a rerun and never counts as an edit.
    module Sentinel
      NOW = '$now'

      module_function

      def now?(value)
        value == NOW
      end

      def resolve(value)
        now?(value) ? Time.current : value
      end
    end
  end
end
