# frozen_string_literal: true

module BetterTogether
  module PlatformsHelper # rubocop:todo Style/Documentation
    PLATFORM_FORM_TAB_ATTRIBUTES = {
      'details' => %i[identifier name description slug host_url time_zone],
      'access' => %i[privacy requires_invitation allow_membership_requests contributors_display_visibility],
      'appearance' => %i[css_block theme header_banner favicon logo content_slot_blocks],
      'security' => %i[csp_frame_ancestors_text csp_frame_src_text csp_img_src_text
                       csp_script_src_text csp_connect_src_text],
      'features' => %i[feature_gate_rollouts quota_default_limits],
      'integrations' => %i[integration_settings]
    }.freeze

    # Number of validation errors per platform form tab, so the tab holding them can be flagged.
    def platform_form_tab_error_counts(platform)
      PLATFORM_FORM_TAB_ATTRIBUTES.transform_values do |attributes|
        platform.errors.count { |error| attributes.include?(error.attribute.to_s.split('.').first.to_sym) }
      end
    end

    # The Integrations tab only exists when an extension gem registered a platform setting.
    def platform_form_tab_ids
      tabs = %w[details access appearance domains security features]
      tabs << 'integrations' if BetterTogether::PlatformSettingsRegistry.any?
      tabs
    end

    # The first tab holding errors, otherwise the details tab.
    def platform_form_active_tab(error_counts)
      error_counts.find { |_tab, count| count.positive? }&.first || 'details'
    end

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
      BetterTogether::Quotas::Type.available(platform).map do |type|
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

    SIZE_UNITS = %w[B KB MB GB TB].freeze

    # Human-readable decimal (SI) size, e.g. 250_000_000 => "250 MB", 1_000_000_000 => "1 GB".
    def quota_size_label(bytes)
      value = bytes.to_f
      unit = 0
      while value >= 1000 && unit < SIZE_UNITS.size - 1
        value /= 1000
        unit += 1
      end
      "#{value.round(2).to_s.sub(/\.0\z/, '')} #{SIZE_UNITS[unit]}"
    end

    # Options for a byte-quota select: a blank "use default" entry, every decimal step,
    # plus the current value when it is not a listed step so it is never silently lost.
    def quota_storage_options(entry)
      steps = (BetterTogether::Quotas::Defaults::STORAGE_STEPS + [entry[:value], entry[:inherited]].compact).uniq.sort
      size = entry[:inherited] ? quota_size_label(entry[:inherited]) : '-'
      default_label = t('better_together.platforms.form.quota_use_default', size:, default: "Use default (#{size})")
      [[default_label, '']] + steps.map { |bytes| [quota_size_label(bytes), bytes] }
    end

    def feature_gate_catalog
      BetterTogether::FeatureRegistry.all.values
    end
  end
end
