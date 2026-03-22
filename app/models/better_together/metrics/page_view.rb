# frozen_string_literal: true

# app/models/better_together/metrics/page_view.rb
module BetterTogether
  module Metrics
    class PageView < ApplicationRecord # rubocop:todo Style/Documentation
      include Utf8UrlHandler

      SENSITIVE_QUERY_PARAMS = %w[token password secret].freeze

      belongs_to :pageable, polymorphic: true

      # Validations
      validates :viewed_at, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }

      # validates :page_url, presence: true

      # Add a method to set the page_url automatically if the pageable responds to a `url` method
      before_validation :set_page_url
      validate :page_url_without_sensitive_parameters

      private

      attr_reader :page_url_query

      # Set the page_url if the pageable object doesn't respond to :url
      def set_page_url # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        url = if pageable.respond_to?(:url)
                pageable.becomes(pageable.class.base_class).url
              elsif pageable.present? && page_url.blank?
                generate_url_for_pageable
              else
                page_url
              end

        return if url.blank?

        # Use our UTF-8 safe URI parser
        uri = safe_parse_uri(url)
        if uri
          @page_url_query = uri.query
          self.page_url = uri.path
        else
          # If we can't parse it at all, add an error
          errors.add(:page_url, 'is invalid')
        end
      end

      def page_url_without_sensitive_parameters
        return if page_url_query.blank?

        params = Rack::Utils.parse_nested_query(page_url_query)
        return unless params.keys.intersect?(SENSITIVE_QUERY_PARAMS)

        errors.add(:page_url, 'contains sensitive parameters')
      end

      # Generate the URL for the pageable using `url_for`
      def generate_url_for_pageable # rubocop:todo Metrics/AbcSize
        Rails.application.routes.url_helpers.polymorphic_url(pageable.becomes(pageable.class.base_class),
                                                             locale: locale)
      rescue NoMethodError
        BetterTogether::Engine.routes.url_helpers.polymorphic_url(pageable.becomes(pageable.class.base_class),
                                                                  locale: locale)
      rescue StandardError
        nil
      end
    end
  end
end
