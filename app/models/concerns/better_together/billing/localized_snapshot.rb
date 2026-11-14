# frozen_string_literal: true

module BetterTogether
  module Billing
    # For a record that keeps a copy of someone else's text as it was when an order was made (a line item's description,
    # a tax line's label, an agreement's title). The copy holds the text of EVERY supported language, so the invoice or
    # receipt can be read, or made again, in any of them without looking at what the source says today.
    #
    #   line_item.snapshot_translations(:description) { |locale| plan.name(locale:, fallback: false) }
    #
    # The block gives the source's text in one language, or nothing; a language the source has no text for is left empty
    # here too, so the reader falls back the way every other translated attribute does.
    module LocalizedSnapshot
      extend ActiveSupport::Concern

      def snapshot_translations(attribute)
        I18n.available_locales.each do |locale|
          value = yield(locale)
          public_send(:"#{attribute}=", value.to_s, locale:) if value.present?
        end
      end
    end
  end
end
