# frozen_string_literal: true

module BetterTogether
  # Persists platform-aware robot configuration for LLM-driven tasks.
  class Robot < ApplicationRecord
    self.table_name = 'better_together_robots'

    ROBOT_TYPES = %w[translation assistant automation].freeze

    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
    has_many :authorships, as: :author, class_name: 'BetterTogether::Authorship', inverse_of: :author, dependent: :restrict_with_exception

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
      provider.presence || ENV.fetch('BETTER_TOGETHER_LLM_PROVIDER', 'openai')
    end

    def chat_model
      default_model.presence || ENV.fetch('BETTER_TOGETHER_LLM_MODEL', 'gpt-4o-mini-2024-07-18')
    end

    def select_option_title
      "#{name} - robot:#{identifier}"
    end

    def to_s
      name
    end

    def embedding_model
      default_embedding_model.presence || ENV.fetch('BETTER_TOGETHER_EMBEDDING_MODEL', 'text-embedding-3-small')
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
