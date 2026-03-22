# frozen_string_literal: true

module BetterTogether
  # Namespace helper for links-related tables. Ensures a consistent
  # table name prefix for models placed under BetterTogether::Links.
  module Links
    def self.table_name_prefix
      'better_together_links_'
    end
  end
end
