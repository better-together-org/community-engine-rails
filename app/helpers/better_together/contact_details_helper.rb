# frozen_string_literal: true

module BetterTogether
  module ContactDetailsHelper # rubocop:todo Style/Documentation
    def render_contact_details(contactable, options = {})
      include_private = options.fetch(:include_private, false)
      contact_detail = contactable.contact_detail
      return ''.html_safe unless contact_detail

      # safe_join, not String#<<: appending literal markup to a SafeBuffer escapes it and the page prints the tags.
      safe_join([
                  content_tag(:div, contact_name_and_role(contact_detail), class: 'name-and-role mb-3'),
                  render_social_media_accounts(contact_detail, include_private:),
                  render_website_links(contact_detail, include_private:),
                  render_email_addresses(contact_detail, include_private:),
                  render_phone_numbers(contact_detail, include_private:),
                  render_addresses(contact_detail, include_private:)
                ])
    end

    def contact_name_and_role(contact_detail)
      parts = [contact_detail.name, contact_detail.role].compact_blank.map { |text| content_tag(:strong, text) }
      safe_join(parts, ', ')
    end

    def render_contacts(contactable, options = {})
      # Options
      include_private = options.fetch(:include_private, false)

      # Fetch the contact detail
      contacts = contactable.contacts
      return ''.html_safe unless contacts

      # Render partials for each contact type
      content = contacts.map do |contact|
        render_contact(contact, include_private:)
      end

      safe_join(content)
    end

    # rubocop:todo-next Metrics/MethodLength
    def render_contact(contact, include_private: false) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      content_tag(:div, class: 'contact mb-3 col') do
        name_and_role = content_tag(:div, class: 'name-and-role mb-3') do
          name = contact.name.present? ? content_tag(:strong, contact.name) : ''.html_safe
          role = contact.role.present? ? ", #{content_tag(:strong, contact.role)}".html_safe : ''.html_safe
          name + role
        end

        name_and_role +
          render_social_media_accounts(contact, include_private:) +
          render_website_links(contact, include_private:) +
          render_phone_numbers(contact, include_private:) +
          render_email_addresses(contact, include_private:) +
          render_addresses(contact, include_private:)
      end
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

    # rubocop:todo-next Metrics/MethodLength
    def social_media_icon_class(platform)
      icon_classes = {
        'Facebook' => 'fab fa-facebook-f',
        'Instagram' => 'fab fa-instagram',
        'Bluesky' => 'fab fa-bluesky',
        'LinkedIn' => 'fab fa-linkedin-in',
        'YouTube' => 'fab fa-youtube',
        'TikTok' => 'fab fa-tiktok',
        'Reddit' => 'fab fa-reddit-alien',
        'WhatsApp' => 'fab fa-whatsapp'
      }
      icon_classes[platform]
    end

    def render_website_links(contact_detail, options = {})
      include_private = options.fetch(:include_private, false)
      website_links = contact_detail.website_links
      website_links = website_links.privacy_public unless include_private

      return ''.html_safe if website_links.empty?

      render partial: 'better_together/website_links/list', locals: { website_links: }
    end
  end
end
