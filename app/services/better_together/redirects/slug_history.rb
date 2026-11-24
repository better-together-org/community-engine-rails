# frozen_string_literal: true

module BetterTogether
  module Redirects
    # Tells whether a slug is a former slug of a record, and what the record's slug is now.
    module SlugHistory
      module_function

      # The record's current slug when `slug` is one it used to have, otherwise nil.
      # A slug that is current in any locale is never treated as old.
      def current_slug_for(record, slug)
        return unless record.respond_to?(:slug) && slug.present?

        current = record.slug
        return if current.blank? || live_slugs(record).include?(slug.to_s)

        current if former_slug?(record, slug)
      end

      def live_slugs(record)
        I18n.available_locales.filter_map { |locale| Mobility.with_locale(locale) { record.slug } }
      end

      def former_slug?(record, slug)
        ::FriendlyId::Slug.exists?(sluggable_type: record.class.base_class.name, sluggable_id: record.id,
                                   slug: slug.to_s)
      end
    end
  end
end
