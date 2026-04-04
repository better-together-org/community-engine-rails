# frozen_string_literal: true

module BetterTogether
  # Adds claim and evidence link support to published and contributed records.
  module Claimable
    extend ActiveSupport::Concern

    included do
      has_many :claims,
               -> { order(:position, :created_at) },
               as: :claimable,
               class_name: 'BetterTogether::Claim',
               dependent: :destroy,
               inverse_of: :claimable

      accepts_nested_attributes_for :claims, allow_destroy: true, reject_if: :all_blank
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          {
            claims_attributes: [
              :id,
              :position,
              :claim_key,
              :statement,
              :selector,
              :review_status,
              :_destroy,
              {
                evidence_links_attributes: %i[
                  id
                  position
                  citation_id
                  relation_type
                  locator
                  quoted_text
                  editor_note
                  review_status
                  _destroy
                ]
              }
            ]
          }
        ]
      end
    end
  end
end
