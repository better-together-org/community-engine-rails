# frozen_string_literal: true

module BetterTogether
  # When included, designates a class as Author
  module Author
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :authored_pages,
               through: :authorships,
               source: :authorable,
               source_type: 'BetterTogether::Page'
      has_many :authored_posts,
               through: :authorships,
               source: :authorable,
               source_type: 'BetterTogether::Post'
    end
  end
end
