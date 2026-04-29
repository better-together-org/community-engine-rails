# frozen_string_literal: true

module BetterTogether
  # Persists platform-aware robot configuration for LLM-driven tasks.
  class Robot < ApplicationRecord # rubocop:todo Metrics/ClassLength
    include Author
    include GovernedAgent

    self.table_name = 'better_together_robots'

    DEFAULT_PROVIDER = 'openai'
    DEFAULT_CHAT_MODEL = 'gpt-4o-mini-2024-07-18'
    DEFAULT_EMBEDDING_MODEL = 'text-embedding-3-small'

    ROBOT_TYPES = %w[translation assistant automation].freeze
    PROVIDERS = %w[openai ollama].freeze
    BOT_ACCESS_SCOPES = %w[
      read_public_content
      read_community_content
      read_private_content
      submit_public_forms
      submit_authenticated_forms
    ].freeze

    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
    has_many :authorships, as: :author, class_name: 'BetterTogether::Authorship', inverse_of: :author, dependent: :restrict_with_exception

    has_many :agreement_participants, as: :participant, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreements, through: :agreement_participants

    validates :name, :identifier, :provider, presence: true
    validates :identifier, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
    validates :robot_type, inclusion: { in: ROBOT_TYPES }
    validates :identifier, uniqueness: { scope: :platform_id }
    validate :global_identifier_unique

    scope :active, -> { where(active: true) }
    scope :global, -> { where(platform_id: nil) }
    scope :for_platform, ->(platform) { where(platform:) }
    scope :by_identifier, ->(identifier) { where(identifier:) }

    def self.available_for_platform(platform = Current.platform)
      relation = active
      return relation.global.order(:name) unless platform

      relation.where(platform_id: [platform.id, nil]).order(:name)
    end

    def self.resolve(identifier:, platform: Current.platform)
      active.for_platform(platform).by_identifier(identifier).first ||
        active.global.by_identifier(identifier).first
    end

    def settings_hash
      raw = self[:settings]
      value = raw.is_a?(String) ? JSON.parse(raw) : raw
      (value || {}).with_indifferent_access
    rescue JSON::ParserError
      {}.with_indifferent_access
    end

    def llm_provider
      provider.presence || ENV.fetch('BETTER_TOGETHER_LLM_PROVIDER', DEFAULT_PROVIDER)
    end

    def chat_model
      default_model.presence || ENV.fetch('BETTER_TOGETHER_LLM_MODEL', DEFAULT_CHAT_MODEL)
    end

    def to_s
      name
    end

    def embedding_model
      default_embedding_model.presence || ENV.fetch('BETTER_TOGETHER_EMBEDDING_MODEL', DEFAULT_EMBEDDING_MODEL)
    end

    def handle
      identifier
    end

    def bot_access_enabled?
      active? && settings_hash[:bot_access_enabled] == true && settings_hash[:bot_access_token_digest].present?
    end

    def bot_access_scopes
      raw_scopes = Array(settings_hash[:bot_access_scopes]).flat_map do |value|
        value.to_s.split(/[,\s]+/)
      end

      raw_scopes.filter_map(&:presence).map(&:to_s).uniq & BOT_ACCESS_SCOPES
    end

    def allows_bot_scope?(scope)
      normalized_scope = scope.to_s
      scopes = bot_access_scopes
      return false unless bot_access_enabled?

      case normalized_scope
      when 'read_public_content'
        scopes.intersect?(%w[read_public_content read_community_content read_private_content])
      when 'read_community_content'
        scopes.intersect?(%w[read_community_content read_private_content])
      when 'read_private_content'
        scopes.include?('read_private_content')
      else
        scopes.include?(normalized_scope)
      end
    end

    def allows_content_privacy?(privacy)
      case privacy.to_s
      when 'public'
        allows_bot_scope?('read_public_content')
      when 'community'
        allows_bot_scope?('read_community_content')
      when 'private'
        allows_bot_scope?('read_private_content')
      else
        false
      end
    end

    def issue_bot_access_token!
      raw_secret = SecureRandom.base58(32)
      updated_settings = settings_hash.merge(
        bot_access_enabled: true,
        bot_access_scopes: bot_access_scopes.presence || %w[read_public_content],
        bot_access_token_digest: self.class.bot_access_token_digest(raw_secret),
        bot_access_token_generated_at: Time.current.iso8601
      )

      update!(settings: updated_settings.to_h)

      "#{identifier}.#{raw_secret}"
    end

    def valid_bot_access_token?(raw_secret)
      return false if raw_secret.blank? || !bot_access_enabled?

      expected_digest = settings_hash[:bot_access_token_digest].to_s
      actual_digest = self.class.bot_access_token_digest(raw_secret)

      return false if expected_digest.blank? || actual_digest.blank?
      return false unless expected_digest.bytesize == actual_digest.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected_digest, actual_digest)
    end

    def self.bot_access_token_digest(raw_secret)
      Digest::SHA256.hexdigest(raw_secret.to_s)
    end

    def self.authenticate_access_token(raw_token, platform: Current.platform)
      identifier, secret = raw_token.to_s.split('.', 2)
      return if identifier.blank? || secret.blank?

      robot = resolve(identifier:, platform:)
      return unless robot&.valid_bot_access_token?(secret)

      robot
    end

    def select_option_title
      "#{name} - @#{identifier} (robot)"
    end

    def managed_by_platform?(candidate_platform)
      platform_id.present? && candidate_platform.present? && platform_id == candidate_platform.id
    end

    def global_fallback?
      platform_id.nil?
    end

    def translation_robot?
      identifier == 'translation' || robot_type == 'translation'
    end

    private

    def global_identifier_unique
      return unless platform_id.nil?

      relation = self.class.global.by_identifier(identifier)
      relation = relation.where.not(id:) if persisted?
      return unless relation.exists?

      errors.add(:identifier, :taken)
    end
  end
end
