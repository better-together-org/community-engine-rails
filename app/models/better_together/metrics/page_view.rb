# app/models/better_together/metrics/page_view.rb
module BetterTogether
  module Metrics
    class PageView < ApplicationRecord
      belongs_to :pageable, polymorphic: true

      # Validations
      validates :viewed_at, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }

      # validates :page_url, presence: true

      # Add a method to set the page_url automatically if the pageable responds to a `url` method
      before_validation :set_page_url

      private

      # Set the page_url if the pageable object doesn't respond to :url
      def set_page_url
        if pageable.respond_to?(:url)
          self.page_url = pageable.url
        else
          self.page_url = generate_url_for_pageable if pageable.present? && page_url.blank?
        end
      end

      # Generate the URL for the pageable using `url_for`
      def generate_url_for_pageable
        # TODO: Fix this so it actually stores the proper urls for things that don't have a url method
        Rails.application.routes.url_helpers.polymorphic_url(pageable)
      rescue
        nil
      end
    end
  end
end
