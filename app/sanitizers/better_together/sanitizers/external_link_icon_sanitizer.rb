# frozen_string_literal: true

# app/sanitizers/better_together/sanitizers/external_link_icon_sanitizer.rb
module BetterTogether
  module Sanitizers
    class ExternalLinkIconSanitizer < Rails::HTML5::SafeListSanitizer # rubocop:todo Style/Documentation
      # rubocop:todo Metrics/MethodLength
      def sanitize(html, options = {}) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        doc = Nokogiri::HTML::DocumentFragment.parse(html)
        host = Rails.application.routes.default_url_options[:host] || 'localhost'

        # Add Font Awesome icon to external links
        doc.css('a[href]').each do |link|
          link_host = begin
            URI.parse(link['href']).host
          rescue StandardError
            nil
          end

          # If the link is external, append the icon
          next unless link_host && link_host != host

          icon = ActionController::Base.helpers.content_tag(:i, '', class: 'fas fa-external-link-alt')
          link.add_child(" #{icon}") # Append the icon to the link text
          link['class'] = [link['class'], 'external-link'].compact.join(' ') # Add a custom class
        end

        super(doc.to_html, options) # Call the parent sanitize method with modified HTML
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
