# frozen_string_literal: true

module BetterTogether
  # View helpers shared by the billing pages (community/person) and the
  # sponsorship panels rendered inside them.
  module BillingHelper
    def sponsorship_counterpart_name(entity)
      return t('globals.unknown', default: 'Unknown') if entity.blank?

      entity.respond_to?(:name) ? entity.name : entity.to_s
    end
  end
end
