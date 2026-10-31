# frozen_string_literal: true

module BetterTogether
  # Write-only +contact_data+ for a Contactable record (a community): the record's own contact details as one JSON
  # string, because JSON:API takes no nested objects. Keys are the contact kinds; each is a list of entries
  # carrying the kind's fields plus a +label+ (any text, CE shows custom labels as written; social accounts have
  # none, their platform is the label) and optional +privacy+ (default public):
  #
  #   {"phone_numbers": [{"number": "709-555-0100", "label": "Box office"}],
  #    "email_addresses": [{"email": "info@example.ca", "label": "General"}],
  #    "website_links": [{"url": "https://example.ca/", "label": "Website"}],
  #    "social_media_accounts": [{"platform_name": "Facebook", "url": "https://...", "handle": "x"}],
  #    "addresses": [{"line1": "5 Park Street", "city_name": "Corner Brook", "label": "Main"}]}
  #
  # A kind that is present replaces that kind's entries (matched on number, email, url, platform and handle, or
  # street address, so repeating the same data changes nothing); a kind that is absent is left alone. An address already
  # in the database, such as the one the record is located at, is reused instead of duplicated, so send the
  # location (+address_data+) before the contact data.
  module ContactData
    LABEL = %w[label].freeze
    KINDS = {
      'phone_numbers' => { keys: %w[number], fields: %w[number] + LABEL },
      'email_addresses' => { keys: %w[email], fields: %w[email] + LABEL },
      'website_links' => { keys: %w[url], fields: %w[url] + LABEL },
      'social_media_accounts' => { keys: %w[platform_name handle], fields: %w[platform_name handle url] },
      'addresses' => { keys: %w[line1 city_name postal_code country_name],
                       extra: { 'physical' => true, 'postal' => false },
                       fields: %w[line1 line2 city_name state_province_name postal_code country_name] + LABEL }
    }.freeze

    def self.included(base)
      base.validate :contact_data_must_be_valid
    end

    def contact_data; end

    def contact_data=(value)
      @contact_data_error = nil
      spec = value.is_a?(String) ? JSON.parse(value) : value.to_h.deep_stringify_keys
      unless spec.is_a?(Hash)
        @contact_data_error = 'must be an object'
        return
      end

      detail = contact_detail || build_contact_detail
      KINDS.each { |kind, config| sync_contacts(detail, kind, config, Array(spec[kind])) if spec.key?(kind) }
    rescue JSON::ParserError
      @contact_data_error = 'is not valid JSON'
    end

    private

    def sync_contacts(detail, kind, config, entries)
      entries = entries.map { |entry| entry.to_h.stringify_keys }
      return @contact_data_error = "#{kind} entries need #{config[:keys].first}" unless complete?(config, entries)

      records = detail.public_send(kind)
      kept = entries.map { |entry| contact_record_for(detail, records, kind, config, entry) }
      records.each { |record| record.mark_for_destruction unless kept.include?(record) }
    end

    def complete?(config, entries)
      entries.all? { |entry| entry[config[:keys].first].present? }
    end

    def contact_record_for(detail, records, kind, config, entry)
      attrs = contact_attributes(config, entry)
      record = existing_contact(records, kind, config, attrs) || records.build
      record.assign_attributes(attrs.merge('contact_detail' => detail))
      records.target << record unless records.target.include?(record)
      record
    end

    def contact_attributes(config, entry)
      attrs = entry.slice(*config[:fields]).transform_values { |value| value.to_s.strip }
      attrs.merge(config.fetch(:extra, {})).merge('privacy' => entry['privacy'].presence || 'public')
    end

    def existing_contact(records, kind, config, attrs)
      found = records.find { |record| config[:keys].all? { |key| record[key].to_s == attrs[key].to_s } }
      return found || reusable_address(attrs, config) if kind == 'addresses'

      found
    end

    def reusable_address(attrs, config)
      ::BetterTogether::Address.find_by(attrs.slice(*config[:keys]).merge(contact_detail_id: nil))
    end

    def contact_data_must_be_valid
      errors.add(:contact_data, @contact_data_error) if @contact_data_error
    end

    private :sync_contacts, :complete?, :contact_record_for, :contact_attributes, :existing_contact,
            :reusable_address, :contact_data_must_be_valid
  end
end
