# frozen_string_literal: true

module ActiveRecord
  # Stand-in so schema.rb can be evaluated without Rails: `ActiveRecord::Schema[7.2]` yields the recorder.
  module Schema
    def self.[](_version)
      Thread.current[:schema_recorder]
    end
  end
end
