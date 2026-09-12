# frozen_string_literal: true

module BetterTogether
  class Category < PlatformRecord # rubocop:todo Style/Documentation
    include Attachments::Images
    include Identifier
    include Metrics::Viewable
    include Positioned
    include Protected
    include Translatable

    attachable_cover_image

    has_many :categorizations, dependent: :destroy
    has_many :pages, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Page'

    translates :name, type: :string
    translates :description, backend: :action_text

    # slug_uniqueness: false — Identifier (included above) already declares a
    # platform-scoped `validates :slug, uniqueness: { scope: :platform_id }`.
    # Leaving this default (true) adds a second, unscoped uniqueness validator
    # on the same column, which rejects legitimate same-slug records on
    # different platforms even though Identifier's own scoping would allow it.
    slugged :name, slug_uniqueness: false

    validates :name, presence: true
    validates :type, presence: true

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        type icon
      ]
    end

    # Distinct categories in use across a relation of categorizable records
    # (e.g. a policy-scoped Posts or Events relation), alphabetically sorted
    # by translated name. Centralizes the "in-use categories" sidebar query
    # so every categorized-resource index shares one join + sort instead of
    # each controller re-deriving it — a locale-fallback-safe or null-safe
    # sort fix made here reaches all callers instead of only one copy.
    #
    # Sorted in Ruby (not a DB-level ORDER BY on the Mobility translation
    # join) deliberately: category counts per index are small, and this
    # avoids a locale-fallback join subtler than the one search_text already
    # does in ContentSearchFilter.
    def self.used_by(relation)
      category_ids = ::BetterTogether::Categorization
                     .where(categorizable_type: relation.klass.name, categorizable_id: relation.select(:id))
                     .select(:category_id)

      where(id: category_ids).with_translations.to_a.sort_by { |category| category.name.to_s.downcase }
    end

    def as_category
      becomes(self.class.base_class)
    end

    configure_attachment_cleanup
  end
end
