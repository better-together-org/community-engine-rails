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
               through: :authorships
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          {
            author_ids: []
          }
        ]
      end
    end
  end
end
