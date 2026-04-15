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
    #   tree_seeds_display(10_000)         # => "1 Tree Seed 🌱"
    #   tree_seeds_display(18_750)         # => "1.875 Tree Seeds 🌱"
    #   tree_seeds_display(100_000)        # => "10 Tree Seeds 🌱"
    #   tree_seeds_display(0)              # => "0 Tree Seeds 🌱"
    #   tree_seeds_display(18_750, include_emoji: false) # => "1.875 Tree Seeds"
    #
    # @param millitokens [Integer, #to_f] Raw millitoken value
    # @param include_emoji [Boolean] Whether to append the 🌱 emoji (default: true)
    # @return [String]
    def tree_seeds_display(millitokens, include_emoji: true)
      c3 = (millitokens.to_f / MILLITOKEN_SCALE).round(4)
      # Strip trailing zeros beyond 2 decimal places for readability
      c3_formatted = c3 == c3.to_i ? c3.to_i.to_s : format('%g', c3)
      label = millitokens.to_i == MILLITOKEN_SCALE ? 'Tree Seed' : 'Tree Seeds'
      emoji = include_emoji ? ' 🌱' : ''
      "#{c3_formatted} #{label}#{emoji}"
    end
  end
end
