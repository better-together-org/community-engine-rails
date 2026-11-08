# frozen_string_literal: true

module BetterTogether
  module Billing
    # One row of a processor-backed select. `text` is shown to the steward as plain text
    # (it is never rendered as HTML).
    LookupOption = Data.define(:value, :text) do
      def to_select_option = { value: value.to_s, text: text.to_s }
    end
  end
end
