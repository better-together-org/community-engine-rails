# frozen_string_literal: true

# config/initializers/action_text.rb
Rails.application.config.to_prepare do
  # Define allowed attributes and tags as needed
  ActionText::ContentHelper.allowed_attributes =
    (Rails::HTML5::Sanitizer.safe_list_sanitizer.allowed_attributes.to_set +
    ActionText::Attachment::ATTRIBUTES.to_set +
    Set.new(%w[style href])).freeze

  # Customize the sanitizer to append icons to external links
  # ActionText::ContentHelper.sanitizer = Rails::HTML5::SafeListSanitizer.new.tap do |sanitizer|
  #   sanitizer.extend(Module.new do
  #     def sanitize(html, options = {})
  #       doc = Nokogiri::HTML::DocumentFragment.parse(html)
  #       host = Rails.application.routes.default_url_options[:host] || 'localhost'

  #       # Process each link to add an icon if it's external
  #       doc.css('a[href]').each do |link|
  #         link_host = URI.parse(link['href']).host rescue nil

  #         # Append Font Awesome icon if link is external
  #         if link_host && link_host != host
  #           icon = ActionController::Base.helpers.content_tag(:i, '', class: 'fas fa-external-link-alt ms-1', style: 'font-size: small;')
  #           link.add_child(" #{icon}") # Append icon to link text
  #           link['class'] = [link['class'], 'external-link'].compact.join(' ') # Add custom class
  #         end
  #       end

  #       super(doc.to_html, options) # Apply the default sanitization
  #     end
  #   end)
  # end
end
