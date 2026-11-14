# frozen_string_literal: true

module BetterTogether
  # A piece of code a platform steward adds to every page head or body, like the header and footer
  # scripts of a WordPress site. It executes in visitors' browsers, so it is guarded: only people with
  # manage_platform_code may edit it, it starts disabled, every change is audited, external script
  # origins must be on the platform's CSP allow-list, and a safe mode switches all snippets off.
  class PlatformSnippet < ApplicationRecord
    include BetterTogether::Positioned

    LOCATIONS = %w[head_start head_end body_start body_end].freeze
    KINDS = %w[script_inline script_src style_inline html_meta].freeze
    CONSENT_CATEGORIES = %w[none analytics marketing].freeze
    APPLIES_TO = %w[all signed_out].freeze
    MAX_CONTENT_LENGTH = 20_000
    META_LINK_RELS = %w[preconnect dns-prefetch canonical alternate me].freeze

    belongs_to :platform, class_name: '::BetterTogether::Platform'
    belongs_to :updated_by, class_name: '::BetterTogether::Person', optional: true

    attr_accessor :allow_csp_origin

    validates :name, presence: true, length: { maximum: 120 }
    validates :location, inclusion: { in: LOCATIONS }
    validates :kind, inclusion: { in: KINDS }
    validates :consent_category, inclusion: { in: CONSENT_CATEGORIES }
    validates :applies_to, inclusion: { in: APPLIES_TO }
    validates :content, length: { maximum: MAX_CONTENT_LENGTH }
    validates :content, presence: true, unless: :script_src?
    validate :content_matches_kind
    validate :src_is_allowed_origin, if: :script_src?
    validate :html_meta_only_in_head

    before_save :stamp_updated_by
    after_create { audit!('created') }
    after_update :audit_update
    after_destroy { audit!('destroyed', attributes.except('content').merge('content_length' => content.to_s.length)) }

    scope :enabled, -> { where(enabled: true) }
    scope :at, ->(location) { where(location:) }

    def position_scope = %i[platform_id location]

    # Imported or federated snippets arrive disabled and wait for steward review.
    def self.build_for_import(platform, attributes)
      new(attributes.to_h.symbolize_keys.slice(:name, :location, :kind, :content, :src, :consent_category,
                                               :applies_to, :notes).merge(platform:, enabled: false))
    end

    def script_src? = kind == 'script_src'
    def script_inline? = kind == 'script_inline'
    def style_inline? = kind == 'style_inline'
    def html_meta? = kind == 'html_meta'
    def head? = location.to_s.start_with?('head')

    def src_origin
      BetterTogether::ContentSecurityPolicySources.origin_for_url(src)
    end

    # Origin already on the platform's script allow-list.
    def origin_allowed?
      src_origin.present? && platform.csp_script_src.include?(src_origin)
    end

    # Parsed <meta> and <link> attributes for html_meta snippets; anything else is dropped.
    def meta_tags
      Nokogiri::HTML.fragment(content.to_s).children.filter_map do |node|
        next unless node.element?

        attrs = node.attributes.transform_values(&:value)
        next unless allowed_meta_tag?(node.name, attrs)

        { name: node.name, attributes: attrs.reject { |key, _| key.start_with?('on') } }
      end
    end

    private

    def stamp_updated_by
      self.updated_by_id = Current.person.id if Current.person
    end

    def audit!(action, changes = saved_changes)
      BetterTogether::PlatformSnippetAudit.record!(snippet: self, action:, changes:)
    end

    def audit_update
      return audit!('updated') unless saved_change_to_enabled?

      audit!(enabled? ? 'enabled' : 'disabled')
    end

    def snippet_error(key, **)
      I18n.t("better_together.platform_snippets.errors.#{key}", **)
    end

    def allowed_meta_tag?(name, attrs)
      return true if name == 'meta'

      name == 'link' && META_LINK_RELS.include?(attrs['rel'].to_s.downcase) &&
        BetterTogether::ContentSecurityPolicySources.origin_for_url(attrs['href']).present?
    end

    def content_matches_kind
      return if content.blank?

      key = content_markup_error
      errors.add(:content, snippet_error(key)) if key
    end

    def content_markup_error
      if script_inline? && content.match?(%r{</script|<!--}i) then :invalid_script_markup
      elsif style_inline? && content.match?(%r{</style|<!--}i) then :invalid_style_markup
      elsif html_meta? && meta_tags.empty? then :invalid_meta_markup
      end
    end

    def src_is_allowed_origin
      return errors.add(:src, snippet_error(:invalid_src)) if src_origin.blank?
      return if origin_allowed? || allow_csp_origin_pending?

      errors.add(:src, snippet_error(:origin_not_allowed, origin: src_origin))
    end

    def allow_csp_origin_pending?
      ActiveModel::Type::Boolean.new.cast(allow_csp_origin) == true
    end

    def html_meta_only_in_head
      errors.add(:location, snippet_error(:meta_requires_head)) if html_meta? && !head?
    end
  end
end
