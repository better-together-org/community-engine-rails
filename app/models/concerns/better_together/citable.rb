# frozen_string_literal: true

module BetterTogether
  # Adds structured citations and bibliography helpers to a record.
  module Citable
    extend ActiveSupport::Concern

    included do
      has_many :citations,
               -> { ordered },
               as: :citeable,
               class_name: 'BetterTogether::Citation',
               dependent: :destroy,
               inverse_of: :citeable

      accepts_nested_attributes_for :citations, allow_destroy: true, reject_if: :all_blank
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          {
            citations_attributes: %i[
              id
              position
              reference_key
              source_kind
              title
              source_author
              publisher
              source_url
              locator
              published_on
              accessed_on
              excerpt
              rights_notes
              _destroy
            ]
          }
        ]
      end
    end

    def citation_for(reference_key)
      citations.find_by(reference_key: reference_key.to_s)
    end

    def bibliography_entries
      citations.ordered
    end

    def citation_reference_options
      bibliography_entries.map do |citation|
        [citation.reference_key, citation.title]
      end
    end
  end
end
