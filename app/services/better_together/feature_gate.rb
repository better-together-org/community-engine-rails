# frozen_string_literal: true

module BetterTogether
  # Resolves actor-aware feature availability against platform rollout state.
  class FeatureGate
    LEVEL_RANKS = {
      none: 0,
      beta: 1,
      alpha: 2
    }.freeze

    class << self
      def enabled?(feature_key, actor:, platform: Current.platform, record: nil)
        new(feature_key, actor:, platform:, record:).enabled?
      end

      def rollout_for(feature_key, platform: Current.platform)
        new(feature_key, actor: nil, platform:).rollout
      end

      def actor_level_for(feature_key, actor:, platform: Current.platform)
        new(feature_key, actor:, platform:).actor_level
      end
    end

    attr_reader :feature_key, :actor, :platform, :record

    def initialize(feature_key, actor:, platform:, record: nil)
      @feature_key = feature_key.to_s
      @actor = actor
      @platform = resolve_platform(platform)
      @record = record
    end

    def enabled?
      case rollout
      when 'stable'
        true
      when 'beta'
        permits_level?(:beta)
      when 'alpha'
        permits_level?(:alpha)
      when 'off'
        explicit_grant_level != :none
      else
        false
      end
    end

    def rollout
      return feature.fetch(:default_rollout) unless platform.present?

      platform.feature_rollout_for(feature_key)
    end

    def actor_level
      maximum_level(role_based_level, explicit_grant_level)
    end

    private

    def feature
      @feature ||= BetterTogether::FeatureRegistry.fetch(feature_key)
    end

    def resolve_platform(candidate)
      candidate || BetterTogether::Platform.find_by(host: true)
    end

    def permits_level?(required_level)
      LEVEL_RANKS.fetch(actor_level, 0) >= LEVEL_RANKS.fetch(required_level)
    end

    def maximum_level(*levels)
      levels.compact.max_by { |level| LEVEL_RANKS.fetch(level, 0) } || :none
    end

    def explicit_grant_level
      return :none unless actor_person.present? && platform.present?

      grant = BetterTogether::FeatureAccessGrant.active.find_by(
        platform:,
        person: actor_person,
        feature_key:
      )
      return :none unless grant.present?

      grant.access_level.to_sym
    end

    def role_based_level
      return :none unless actor_person.present? && platform.present?
      return :alpha if actor_person.permitted_to?('access_alpha_features', platform)
      return :beta if actor_person.permitted_to?('access_beta_features', platform)

      :none
    end

    def actor_person
      @actor_person ||= case actor
                        when BetterTogether::User
                          actor.person
                        when BetterTogether::Person
                          actor
                        end
    end
  end
end
