# frozen_string_literal: true

module BetterTogether
  module Geography
    module Location
      extend ActiveSupport::Concern

      included do
        before_validation :normalize_iso_code

        validates :iso_code, presence: true, uniqueness: { case_sensitive: false }
        validate :iso_code_format

        def to_s
          name
        end
      end

      private

      def normalize_iso_code
        self.iso_code = iso_code.to_s.upcase
      end

      def iso_code_format
        char_length, format_regex = case self.class.name.demodulize
                                    when 'Country'
                                      [2, /\A[A-Z]{2}\z/]
                                    when 'State', 'Region'
                                      [5, /\A[A-Z0-9\-]{1,5}\z/]
                                    else
                                      [nil, nil]
                                    end
        if iso_code.length != char_length || iso_code !~ format_regex
          errors.add(:iso_code, "must be #{char_length} characters and match format #{format_regex}")
        end
      end
    end
  end
end
