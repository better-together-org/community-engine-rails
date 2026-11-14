# frozen_string_literal: true

module BetterTogether
  # View helpers for listing quotas whose type is available on the current platform.
  module QuotasHelper
    # Drops quotas of types that are not offered (e.g. LLM tokens with no AI provider).
    def visible_quotas(quotas, platform = Current.platform)
      available = BetterTogether::Quotas::Type.available_keys(platform)
      Array(quotas).select { |quota| available.include?(quota.quota_type) }
    end

    def quota_type_label(key)
      t("better_together.quotas.usage_meter.types.#{key}", default: key.to_s.titleize)
    end
  end
end
