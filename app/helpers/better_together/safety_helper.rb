# frozen_string_literal: true

module BetterTogether
  # Translation helpers for safety reporting and moderation interfaces.
  module SafetyHelper
    def safety_text(key, **)
      t("better_together.safety.#{key}", **)
    end

    def safety_enum_label(scope, value)
      safety_text("#{scope}.#{value}", default: value.to_s.humanize)
    end

    def safety_enum_options(scope, values, include_any: false)
      options = values.map { |value| [safety_enum_label(scope, value), value] }
      include_any ? [[safety_text('shared.any'), nil]] + options : options
    end
  end
end
