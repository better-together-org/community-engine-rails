# frozen_string_literal: true

module BetterTogether
  # Transitional contributor concern backed by BetterTogether::Authorship records.
  module Author
    extend ActiveSupport::Concern

    included do
      has_many :contributions,
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :authorships,
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :page_contributions,
               -> { where(authorable_type: 'BetterTogether::Page') },
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :post_contributions,
               -> { where(authorable_type: 'BetterTogether::Post') },
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :page_authorships,
               -> { where(authorable_type: 'BetterTogether::Page', role: BetterTogether::Authorship::AUTHOR_ROLE) },
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :post_authorships,
               -> { where(authorable_type: 'BetterTogether::Post', role: BetterTogether::Authorship::AUTHOR_ROLE) },
               as: :author,
               class_name: 'BetterTogether::Authorship',
               inverse_of: :author
      has_many :authored_pages,
               through: :page_authorships,
               source: :authorable,
               source_type: 'BetterTogether::Page'
      has_many :authored_posts,
               through: :post_authorships,
               source: :authorable,
               source_type: 'BetterTogether::Post'
      has_many :contributed_pages,
               through: :page_contributions,
               source: :authorable,
               source_type: 'BetterTogether::Page'
      has_many :contributed_posts,
               through: :post_contributions,
               source: :authorable,
               source_type: 'BetterTogether::Post'
    end
  end
end
