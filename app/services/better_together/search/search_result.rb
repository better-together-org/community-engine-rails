# frozen_string_literal: true

module BetterTogether
  module Search
    # A normalized search response from a backend.
    SearchResult = Struct.new(
      :records,
      :suggestions,
      :status,
      :backend,
      :error
    )
  end
end
