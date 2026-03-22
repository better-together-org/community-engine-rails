# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Provides category options as [translated_name, id] sorted by name, honoring Mobility fallbacks
    class CategoryOptions
      def self.call(relation = BetterTogether::Joatu::Category.all)
        new(relation).call
      end

      def initialize(relation)
        @relation = relation
      end

      def call
        cats = @relation.to_a
        cats.sort_by! { |c| c.name.to_s.downcase }
        cats.map { |c| [c.name, c.id] }
      end
    end
  end
end
