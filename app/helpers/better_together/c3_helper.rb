# frozen_string_literal: true

module BetterTogether
  # Helpers for displaying C3 community currency amounts.
  #
  # The human unit for C3 is "Tree Seeds 🌱" (BCC branding — an NL-vernacular
  # pronunciation of "three").  Millitokens are a wire format; no user should
  # ever see them in the UI.
  module C3Helper
    MILLITOKEN_SCALE = BetterTogether::C3::Token::MILLITOKEN_SCALE

    # Format a millitoken integer as a human-readable Tree Seeds amount.
    #
    # Examples:
    #   tree_seeds_display(1_000)         # => "1 Tree Seed 🌱"
    #   tree_seeds_display(1_875)         # => "1.875 Tree Seeds 🌱"
    #   tree_seeds_display(10_000)        # => "10 Tree Seeds 🌱"
    #   tree_seeds_display(0)             # => "0 Tree Seeds 🌱"
    #   tree_seeds_display(1_875, include_emoji: false) # => "1.875 Tree Seeds"
    #
    # @param millitokens [Integer, #to_f] Raw millitoken value
    # @param include_emoji [Boolean] Whether to append the 🌱 emoji (default: true)
    # @return [String]
    def tree_seeds_display(millitokens, include_emoji: true)
      c3 = (millitokens.to_f / MILLITOKEN_SCALE).round(4)
      c3_formatted = c3 == c3.to_i ? c3.to_i.to_s : format('%g', c3)
      unit_count = millitokens.to_i == MILLITOKEN_SCALE ? 1 : 2
      emoji = include_emoji ? I18n.t('better_together.c3.tree_seed_emoji', default: ' 🌱') : ''
      label = I18n.t('better_together.c3.tree_seed', count: unit_count,
                                                     default: { one: 'Tree Seed', other: 'Tree Seeds' })
      I18n.t('better_together.c3.tree_seed_display',
             amount: c3_formatted, unit: label, emoji: emoji,
             default: '%<amount>s %<unit>s%<emoji>s')
    end
  end
end
