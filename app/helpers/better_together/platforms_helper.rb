# frozen_string_literal: true

module BetterTogether
  module PlatformsHelper # rubocop:todo Style/Documentation
    # Get invitation token expiry timestamp for any invitation type
    # Checks all invitation types (platform, community, event) and returns the first one found
    def invitation_token_expires_at
      invitation_types = %w[platform community event]

      invitation_types.each do |type|
        expires_key = :"#{type}_invitation_expires_at"
        next unless session[expires_key].present?

        time = session[expires_key]
        # Convert to Time object if it's a string, then get Unix timestamp
        time = Time.parse(time) if time.is_a?(String)
        return time.to_i
      end

      nil
    end

    # Get the active invitation token for any invitation type
    def active_invitation_token
      invitation_types = %w[platform community event]

      invitation_types.each do |type|
        token_key = :"#{type}_invitation_token"
        return session[token_key] if session[token_key].present?
      end

      nil
    end

    def feature_gate_rollout_options
      BetterTogether::FeatureRegistry::VALID_ROLLOUTS.map do |rollout|
        [rollout.humanize, rollout]
      end
    end

    # [{ key:, unit:, kinds: [{ kind:, field:, value:, inherited: }] }] for the
    # platform form's quota defaults card. `value` is the platform's own override
    # (blank = inherit) and `inherited` the YAML default shown as the placeholder.
    def quota_default_catalog(platform)
      BetterTogether::Quotas::Type.all.map do |type|
        {
          key: type.key, unit: type.unit,
          kinds: BetterTogether::Quotas::Defaults::OWNER_KINDS.map do |kind|
            {
              kind:, field: "platform[quota_default_limits][#{type.key}][#{kind}]",
              value: BetterTogether::Quotas::Defaults.platform_value(platform, type.key, kind),
              inherited: BetterTogether::Quotas::Defaults.yaml_value(type.key, kind)
            }
          end
        }
      end
    end

    def feature_gate_catalog
      BetterTogether::FeatureRegistry.all.values
    end
  end
end
