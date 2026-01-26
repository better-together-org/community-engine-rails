# frozen_string_literal: true

module BetterTogether
  # Concern that when included makes the model act as an identity
  module Publishable
    extend ActiveSupport::Concern

    included do
      def self.draft
        where(arel_table[:published_at].eq(nil))
      end

      def self.published
        where(arel_table[:published_at].lteq(Time.current))
      end

      def self.scheduled
        where(arel_table[:published_at].gt(Time.current))
      end

      def draft?
        published_at.nil?
      end

      def published?
        return false if published_at.nil?

        published_at <= Time.current
      end

      def scheduled?
        return false if published_at.nil?

        published_at >= Time.current
      end
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          :published_at
        ]
      end
    end
  end
end
