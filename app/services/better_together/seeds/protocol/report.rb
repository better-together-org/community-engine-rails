# frozen_string_literal: true

module BetterTogether
  module Seeds
    module Protocol
      # Structured validation outcome. Errors are addressed by file and record so that a
      # large packet reports every problem at once instead of the first flattened string.
      class Report
        Error = Data.define(:file, :record, :field, :message) do
          def to_h
            { file:, record:, field:, message: }
          end
        end

        attr_reader :errors, :warnings

        def initialize
          @errors = []
          @warnings = []
        end

        def add_error(file:, message:, record: nil, field: nil)
          @errors << Error.new(file, record, field, message)
        end

        def add_warning(file:, message:, record: nil, field: nil)
          @warnings << Error.new(file, record, field, message)
        end

        def valid?
          errors.empty?
        end

        def to_h
          { valid: valid?, errors: errors.map(&:to_h), warnings: warnings.map(&:to_h) }
        end
      end
    end
  end
end
