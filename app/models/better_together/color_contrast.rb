# frozen_string_literal: true

module BetterTogether
  # WCAG 2.x contrast maths for hex colours, so a user supplied background always gets readable text on it.
  module ColorContrast
    LIGHT = '#ffffff'
    DARK = '#111111'

    module_function

    # Whichever of white or near-black has the higher contrast on the background (always at least 4.5:1).
    def text_color_for(background)
      contrast_ratio(background, LIGHT) >= contrast_ratio(background, DARK) ? LIGHT : DARK
    end

    def contrast_ratio(first, second)
      lighter, darker = [luminance(first), luminance(second)].sort.reverse
      (lighter + 0.05) / (darker + 0.05)
    end

    def luminance(hex)
      red, green, blue = hex.delete('#').scan(/../).map { |pair| linear(pair.hex / 255.0) }
      (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    end

    def linear(channel)
      channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
  end
end
