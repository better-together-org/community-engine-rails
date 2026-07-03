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

    def as_category
      becomes(self.class.base_class)
    end

    configure_attachment_cleanup
  end
end
