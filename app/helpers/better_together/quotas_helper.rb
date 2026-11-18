# frozen_string_literal: true

module BetterTogether
  # View helpers for listing quotas whose type is available on the current platform.
  module QuotasHelper
    # Drops quotas whose type is not offered on the platform (e.g. LLM tokens with no
    # working translation provider) and rows the type hides for their owner (e.g. LLM
    # tokens with an effective limit of 0). Both usage tabs and the admin overview use this.
    def visible_quotas(quotas, platform = Current.platform)
      available = BetterTogether::Quotas::Type.available(platform).index_by(&:key)
      Array(quotas).select do |quota|
        type = available[quota.quota_type]
        type.present? && type.visible_for?(quota)
      end
    end

    def quota_type_label(key)
      t("better_together.quotas.usage_meter.types.#{key}", default: key.to_s.titleize)
    end
  end
end
