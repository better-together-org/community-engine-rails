# frozen_string_literal: true

module BetterTogether
  # When included, designates a class as Authorable
  module Authorable
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               -> { positioned },
               as: :authorable
      has_many :authors,
               -> { where(better_together_authorships: { author_type: 'BetterTogether::Person' }) },
               through: :authorships,
               source: :author,
               source_type: 'BetterTogether::Person'
      has_many :robot_authors,
               -> { where(better_together_authorships: { author_type: 'BetterTogether::Robot' }) },
               through: :authorships,
               source: :author,
               source_type: 'BetterTogether::Robot'
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          {
            author_ids: [],
            robot_author_ids: []
          }
        ]
      end
    end

    def governed_authors
      authorships.includes(:author).sort_by(&:position).map(&:author).compact
    end
  end
end
