# frozen_string_literal: true

require 'storext'

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord # rubocop:disable Metrics/ClassLength
    include PlatformHost
    include PlatformRegistryDefaults
    include PlatformFederationStatus
    include PlatformCspConfiguration
    include PlatformCssBlockManagement
    include PlatformMembershipDisplay
    include Creatable
    include Identifier
    include Joinable
    include Metrics::Viewable
    include Permissible
    include PrimaryCommunity
    include Privacy
    include Protected
    include TimezoneAttributeAliasing
    include RemoveableAttachment
    include ::Storext.model

    NETWORK_VISIBILITIES = %w[private peer member public].freeze
    CONNECTION_BOOTSTRAP_STATES = %w[pending_host_request pending_review connected opted_out disabled].freeze
    FEDERATION_PROTOCOLS = %w[ce_oauth oauth2 openid_connect custom].freeze
    SOFTWARE_VARIANTS = %w[community_engine generic].freeze
    SEARCH_QUERY_ANALYTICS_MODES = %w[full hashed].freeze

    has_community

    joinable joinable_type: 'platform',
             member_type: 'person'

    has_many :invitations,
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    # For performance - scope to limit invitations in some contexts
    has_many :recent_invitations,
             -> { where(created_at: 30.days.ago..) },
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    slugged :name

    store_attributes :settings do
      requires_invitation Boolean, default: true
      allow_membership_requests Boolean, default: false
      contributors_display_visibility String, default: 'on'
      software_variant String
      network_visibility String, default: 'private'
      connection_bootstrap_state String
      federation_protocol String
      oauth_issuer_url String
      search_query_analytics_enabled Boolean, default: true
      search_query_analytics_mode String, default: 'full'
    end

    # Alias the database url column to host_url for clarity
    alias_attribute :host_url, :url

    validates :host_url, presence: true, uniqueness: true,
                         format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
    validate :host_url_ssrf_safe
    validates :time_zone,
              presence: true,
              inclusion: {
                in: -> { TZInfo::Timezone.all_identifiers },
                message: '%<value>s is not a valid timezone'
              }
    validates :external, inclusion: { in: [true, false] }
    validates :software_variant, inclusion: { in: SOFTWARE_VARIANTS }, allow_blank: true
    validates :network_visibility, inclusion: { in: NETWORK_VISIBILITIES }
    validates :connection_bootstrap_state, inclusion: { in: CONNECTION_BOOTSTRAP_STATES }
    validates :federation_protocol, inclusion: { in: FEDERATION_PROTOCOLS }, allow_blank: true
    validates :search_query_analytics_mode, inclusion: { in: SEARCH_QUERY_ANALYTICS_MODES }
    validates :contributors_display_visibility,
              inclusion: { in: BetterTogether::Authorable::EFFECTIVE_CONTRIBUTOR_DISPLAY_VISIBILITIES }
    validates :oauth_issuer_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
    validate :oauth_issuer_url_ssrf_safe
    validate :require_publishing_agreement_for_public_network_visibility

    after_initialize :set_default_requires_invitation, if: :new_record?
    before_validation :apply_platform_registry_defaults

    # Class method for permitted attributes - used by controllers for strong parameters
    # @return [Array] List of permitted attributes and nested hashes
    def self.permitted_attributes
      [
        :name, :slug, :host_url, :time_zone, :external, :protected,
        :storage_configuration_id,
        :csp_frame_ancestors_text, :csp_frame_src_text, :csp_img_src_text,
        :csp_script_src_text, :csp_connect_src_text,
        { settings: %i[requires_invitation allow_membership_requests
                       software_variant network_visibility connection_bootstrap_state
                       federation_protocol oauth_issuer_url search_query_analytics_enabled
                       search_query_analytics_mode contributors_display_visibility
                       feature_gate_rollouts] }
      ] + super
    end

    scope :external, -> { where(external: true) }
    scope :internal, -> { where(external: false) }
    scope :oauth_providers, -> { external }

    has_one_attached :profile_image
    has_one_attached :cover_image

    has_one :sitemap, class_name: '::BetterTogether::Sitemap', dependent: :destroy

    has_many :platform_blocks, dependent: :destroy, class_name: 'BetterTogether::Content::PlatformBlock'
    has_many :blocks, through: :platform_blocks
    has_many :platform_domains, class_name: '::BetterTogether::PlatformDomain', dependent: :destroy
    has_many :outgoing_platform_connections,
             class_name: '::BetterTogether::PlatformConnection',
             foreign_key: :source_platform_id,
             dependent: :destroy,
             inverse_of: :source_platform
    has_many :incoming_platform_connections,
             class_name: '::BetterTogether::PlatformConnection',
             foreign_key: :target_platform_id,
             dependent: :destroy,
             inverse_of: :target_platform

    after_commit :sync_primary_platform_domain!, on: %i[create update]

    has_many :storage_configurations,
             class_name: 'BetterTogether::StorageConfiguration',
             dependent: :destroy

    has_many :robots,
             class_name: 'BetterTogether::Robot',
             dependent: :destroy
    has_many :feature_access_grants,
             class_name: 'BetterTogether::FeatureAccessGrant',
             dependent: :destroy

    belongs_to :active_storage_configuration,
               class_name: 'BetterTogether::StorageConfiguration',
               foreign_key: :storage_configuration_id,
               optional: true

    def cache_key
      "#{super}/#{css_block&.updated_at&.to_i}"
    end

    def primary_platform_domain
      return unless self.class.connection.data_source_exists?('better_together_platform_domains')

      platform_domains.where(primary_flag: true).active.first
    end

    def share_platform_domain
      return unless self.class.connection.data_source_exists?('better_together_platform_domains')

      platform_domains.share_domain_active.first
    end

    def share_base_url
      share_platform_domain&.url || resolved_host_url
    end

    def resolved_host_url
      primary_platform_domain&.url || host_url
    end

    # Route URL for the platform resource within the current host app.
    # Keep the persisted `url` column available for the platform host URL.
    def route_url(locale: I18n.locale)
      return nil unless persisted?

      BetterTogether::Engine.routes.url_helpers.platform_url(self, locale:)
    end

    def primary_community_extra_attrs
      { host:, protected: }
    end

    # External platforms (OAuth identity providers like GitHub) always get a
    # private primary community regardless of their own `privacy` value (see
    # PrimaryCommunity#primary_community_privacy) — that community is a
    # structural placeholder, never a real user-facing space. Exempt these
    # platforms from the ceiling check so their own `privacy` (e.g. 'public',
    # used for federation/display purposes) isn't blocked by their
    # intentionally-private placeholder community.
    def privacy_ceiling_exempt?
      external?
    end

    def membership_requests_enabled_for?(community = primary_community)
      allow_membership_requests? && (community&.membership_requests_enabled?(platform: self) || false)
    end

    def feature_gate_rollouts
      raw_rollouts = settings.fetch('feature_gate_rollouts', {})
      raw_rollouts.is_a?(Hash) ? raw_rollouts.stringify_keys : {}
    end

    def feature_gate_rollouts=(value)
      normalized = value.respond_to?(:to_h) ? value.to_h : value
      sanitized = sanitize_feature_gate_rollouts(normalized)
      self.settings = settings.merge('feature_gate_rollouts' => sanitized)
    end

    def feature_rollout_for(feature_key)
      registry_entry = BetterTogether::FeatureRegistry.find(feature_key)
      return 'off' unless registry_entry

      feature_gate_rollouts.fetch(
        feature_key.to_s,
        registry_entry.fetch(:default_rollout)
      )
    end

    def to_s
      name
    end

    private

    def set_default_requires_invitation
      self.requires_invitation = true if requires_invitation.nil?
    end

    def host_url_ssrf_safe
      BetterTogether::SafeFederationUrlValidator
        .new(attributes: [:host_url])
        .validate_each(self, :host_url, host_url)
    end

    def oauth_issuer_url_ssrf_safe
      return if oauth_issuer_url.blank?

      BetterTogether::SafeFederationUrlValidator
        .new(attributes: [:oauth_issuer_url])
        .validate_each(self, :oauth_issuer_url, oauth_issuer_url)
    end

    def require_publishing_agreement_for_public_network_visibility
      return unless network_visibility == 'public'
      return unless new_record? || will_save_change_to_network_visibility?

      BetterTogether::PublicVisibilityGate.allow!(
        record: self,
        actor: Current.governed_agent,
        target_network_visibility: network_visibility
      )
    end

    def sanitize_feature_gate_rollouts(value)
      return {} unless value.is_a?(Hash)

      allowed_keys = BetterTogether::FeatureRegistry.keys
      allowed_rollouts = BetterTogether::FeatureRegistry::VALID_ROLLOUTS

      value.each_with_object({}) do |(key, rollout), sanitized|
        next unless allowed_keys.include?(key.to_s)
        next unless allowed_rollouts.include?(rollout.to_s)

        sanitized[key.to_s] = rollout.to_s
      end
    end
  end
end
