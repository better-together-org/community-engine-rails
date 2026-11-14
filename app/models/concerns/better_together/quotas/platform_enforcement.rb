# frozen_string_literal: true

module BetterTogether
  module Quotas
    # How strictly a platform enforces each kind of quota (storage, AI tokens). A steward chooses, per
    # type, between `off`, `shadow` (record only; the default), `soft` (record and warn) and `hard` (refuse new
    # consumption past the limit). Kept in the platform's settings; included into Platform.
    module PlatformEnforcement
      extend ActiveSupport::Concern

      MODES = %w[off shadow soft hard].freeze
      DEFAULT_MODE = 'shadow'

      class InvalidMode < ArgumentError; end

      def quota_enforcement_mode(type_key)
        mode = settings.to_h.dig('quota_enforcement', type_key.to_s)
        MODES.include?(mode) ? mode : DEFAULT_MODE
      end

      # Switches one quota type for every quota on this platform (existing and future).
      def set_quota_enforcement!(type_key, mode)
        raise InvalidMode, "unknown mode #{mode.inspect}" unless MODES.include?(mode.to_s)
        raise InvalidMode, "unknown quota type #{type_key.inspect}" unless BetterTogether::Quotas::Type.keys.include?(type_key.to_s)

        update!(settings: settings.to_h.deep_merge('quota_enforcement' => { type_key.to_s => mode.to_s }))
        BetterTogether::Quotas.apply_enforcement!(self, type_key)
      end
    end
  end
end
