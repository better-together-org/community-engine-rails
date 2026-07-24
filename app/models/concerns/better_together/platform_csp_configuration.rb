# frozen_string_literal: true

module BetterTogether
  # CSP origin configuration for Platform: accessors, validation, and settings persistence.
  module PlatformCspConfiguration
    extend ActiveSupport::Concern

    CSP_SETTING_KEYS = {
      csp_frame_ancestors_text: 'csp_frame_ancestors',
      csp_frame_src_text: 'csp_frame_src',
      csp_img_src_text: 'csp_img_src',
      csp_script_src_text: 'csp_script_src',
      csp_connect_src_text: 'csp_connect_src'
    }.freeze

    DEFAULT_LOCAL_CSP_IMG_SOURCES = [
      'https://*.tile.openstreetmap.org'
    ].freeze

    attr_writer :csp_frame_ancestors_text, :csp_frame_src_text, :csp_img_src_text,
                :csp_script_src_text, :csp_connect_src_text

    included do
      # persist_csp_origin_settings must run before seed_default_local_csp_settings:
      # it fully replaces settings[setting_key] from any explicitly-assigned text
      # attribute, so if it ran second on create it would clobber the seeded
      # defaults merged in by seed_default_local_csp_settings. Running it first lets
      # the create-time seeding merge with (rather than get overwritten by) any
      # csp_img_src_text explicitly provided at create.
      before_validation :persist_csp_origin_settings
      before_validation :seed_default_local_csp_settings, on: :create
      validate :validate_csp_origin_text_fields
    end

    def csp_frame_ancestors
      csp_setting_values('csp_frame_ancestors')
    end

    def csp_frame_src
      csp_setting_values('csp_frame_src')
    end

    def csp_img_src
      csp_setting_values('csp_img_src')
    end

    def csp_script_src
      csp_setting_values('csp_script_src')
    end

    def csp_connect_src
      csp_setting_values('csp_connect_src')
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

    def csp_script_src_text
      @csp_script_src_text || csp_script_src.join("\n")
    end

    def csp_connect_src_text
      @csp_connect_src_text || csp_connect_src.join("\n")
    end

    private

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

    def seed_default_local_csp_settings
      return if external?

      updated_settings = settings.deep_dup
      updated_settings['csp_img_src'] = merge_csp_setting_values(
        updated_settings['csp_img_src'],
        DEFAULT_LOCAL_CSP_IMG_SOURCES
      )
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

    def merge_csp_setting_values(existing_values, additional_values)
      BetterTogether::ContentSecurityPolicySources.merged_sources(
        Array(existing_values).filter_map do |value|
          BetterTogether::ContentSecurityPolicySources.normalize_origin(value)
        end,
        Array(additional_values).filter_map do |value|
          BetterTogether::ContentSecurityPolicySources.normalize_origin(value)
        end
      )
    end
  end
end
