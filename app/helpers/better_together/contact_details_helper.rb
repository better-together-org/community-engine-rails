# frozen_string_literal: true

module BetterTogether
  module ContactDetailsHelper # rubocop:todo Style/Documentation
    def render_contact_details(contactable, options = {})
      # Options
      include_private = options.fetch(:include_private, false)

      # Fetch the contact detail
      contact_detail = contactable.contact_detail
      return ''.html_safe unless contact_detail

      # Render partials for each contact type
      content = ''.html_safe
      content << render_social_media_accounts(contact_detail, include_private:)
      content << render_website_links(contact_detail, include_private:)
      content << render_phone_numbers(contact_detail, include_private:)
      content << render_email_addresses(contact_detail, include_private:)
      content << render_addresses(contact_detail, include_private:)
      content
    end

    def render_phone_numbers(contact_detail, options = {})
      include_private = options.fetch(:include_private, false)
      phone_numbers = contact_detail.phone_numbers
      phone_numbers = phone_numbers.privacy_public unless include_private

      return ''.html_safe if phone_numbers.empty?

      render partial: 'better_together/phone_numbers/list', locals: { phone_numbers: }
    end

    def render_email_addresses(contact_detail, options = {})
      include_private = options.fetch(:include_private, false)
      email_addresses = contact_detail.email_addresses
      email_addresses = email_addresses.privacy_public unless include_private

      return ''.html_safe if email_addresses.empty?

      render partial: 'better_together/email_addresses/list', locals: { email_addresses: }
    end

    def render_addresses(contact_detail, options = {})
      include_private = options.fetch(:include_private, false)
      addresses = contact_detail.addresses
      addresses = addresses.privacy_public unless include_private

      return ''.html_safe if addresses.empty?

      render partial: 'better_together/addresses/list', locals: { addresses: }
    end

    def render_social_media_accounts(contact_detail, options = {})
      return if contact_detail.nil?

      include_private = options.fetch(:include_private, false)
      social_media_accounts = contact_detail.social_media_accounts
      social_media_accounts = social_media_accounts.privacy_public unless include_private

      return ''.html_safe if social_media_accounts.empty?

      render partial: 'better_together/social_media_accounts/list',
             locals: { social_media_accounts: }
    end

    def render_host_community_social_media_accounts(include_private: false)
      contact_detail = host_community.contact_detail
      return unless contact_detail

      social_media_accounts = contact_detail.social_media_accounts.to_a
      social_media_accounts = social_media_accounts.select(&:privacy_public?) unless include_private
      return if social_media_accounts.empty?

      render partial: 'better_together/social_media_accounts/navbar',
             locals: { social_media_accounts: }
    end

    # rubocop:todo Metrics/MethodLength
    def social_media_icon_class(platform) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
      case platform
      when 'Facebook'
        'fab fa-facebook-f'
      when 'Instagram'
        'fab fa-instagram'
      when 'Bluesky'
        'fab fa-bluesky'
      when 'LinkedIn'
        'fab fa-linkedin-in'
      when 'YouTube'
        'fab fa-youtube'
      when 'TikTok'
        'fab fa-tiktok'
      when 'Reddit'
        'fab fa-reddit-alien'
      when 'WhatsApp'
        'fab fa-whatsapp'
      end
    end
    # rubocop:enable Metrics/MethodLength

    def render_website_links(contact_detail, options = {})
      include_private = options.fetch(:include_private, false)
      website_links = contact_detail.website_links
      website_links = website_links.privacy_public unless include_private

      return ''.html_safe if website_links.empty?

      render partial: 'better_together/website_links/list', locals: { website_links: }
    end
  end
end
