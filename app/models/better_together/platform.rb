# frozen_string_literal: true

require 'storext'

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord # rubocop:disable Metrics/ClassLength
    include PlatformHost
    include PlatformRegistryDefaults
    include PlatformFederationStatus
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
    include ::Storext.model

    NETWORK_VISIBILITIES = %w[private peer member public].freeze
    CONNECTION_BOOTSTRAP_STATES = %w[pending_host_request pending_review connected opted_out disabled].freeze
    FEDERATION_PROTOCOLS = %w[ce_oauth oauth2 openid_connect custom].freeze
    SOFTWARE_VARIANTS = %w[community_engine generic].freeze
    SEARCH_QUERY_ANALYTICS_MODES = %w[full hashed].freeze
    CSP_SETTING_KEYS = {
      csp_frame_ancestors_text: 'csp_frame_ancestors',
      csp_frame_src_text: 'csp_frame_src',
      csp_img_src_text: 'csp_img_src'
    }.freeze

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
      requires_invitation Boolean, default: false
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
    validates :oauth_issuer_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
    validate :oauth_issuer_url_ssrf_safe
    validate :validate_csp_origin_text_fields

    before_validation :apply_platform_registry_defaults
    before_validation :persist_csp_origin_settings

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

    belongs_to :active_storage_configuration,
               class_name: 'BetterTogether::StorageConfiguration',
               foreign_key: :storage_configuration_id,
               optional: true

    # Virtual attributes to track removal
    attr_accessor :remove_profile_image, :remove_cover_image
    attr_writer :csp_frame_ancestors_text, :csp_frame_src_text, :csp_img_src_text

    # Callbacks to remove images if necessary
    before_save :purge_profile_image, if: -> { remove_profile_image == '1' }
    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }

    def csp_frame_ancestors
      csp_setting_values('csp_frame_ancestors')
    end

    def csp_frame_src
      csp_setting_values('csp_frame_src')
    end

    def csp_img_src
      csp_setting_values('csp_img_src')
    end

    def csp_frame_ancestors_text
      @csp_frame_ancestors_text || csp_frame_ancestors.join("\n")
    end

    def csp_frame_src_text
      @csp_frame_src_text || csp_frame_src.join("\n")
    end

    def csp_img_src_text
      @csp_img_src_text || csp_img_src.join("\n")
    end

    def cache_key
      "#{super}/#{css_block&.updated_at&.to_i}"
    end

    def primary_platform_domain
      return unless self.class.connection.data_source_exists?('better_together_platform_domains')

      platform_domains.primary.active.first
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

    def to_s
      name
    end

    private

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

    def persist_csp_origin_settings
      updated_settings = settings.deep_dup

      CSP_SETTING_KEYS.each do |text_attribute, setting_key|
        next unless instance_variable_defined?(:"@#{text_attribute}")

        normalized_values = BetterTogether::ContentSecurityPolicySources
                            .parse_origin_list(public_send(text_attribute))

        if normalized_values.empty?
          updated_settings.delete(setting_key)
        else
          updated_settings[setting_key] = normalized_values
        end
      end

      self.settings = updated_settings
    end

    def validate_csp_origin_text_fields
      CSP_SETTING_KEYS.each_key do |text_attribute|
        next unless instance_variable_defined?(:"@#{text_attribute}")

        invalid_values = BetterTogether::ContentSecurityPolicySources.invalid_origins(public_send(text_attribute))
        next if invalid_values.empty?

        errors.add(
          text_attribute,
          "contains invalid origins: #{invalid_values.join(', ')}. Use HTTPS origins or hostnames only."
        )
      end
    end

    def csp_setting_values(setting_key)
      Array(settings[setting_key]).filter_map do |value|
        BetterTogether::ContentSecurityPolicySources.normalize_origin(value)
      end.uniq
    end
  end
end
