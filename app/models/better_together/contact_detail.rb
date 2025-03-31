# frozen_string_literal: true

module BetterTogether
  class ContactDetail < ApplicationRecord # rubocop:todo Style/Documentation
    belongs_to :contactable, polymorphic: true, touch: true

    has_many :phone_numbers, dependent: :destroy, class_name: 'BetterTogether::PhoneNumber'
    has_many :email_addresses, dependent: :destroy, class_name: 'BetterTogether::EmailAddress'
    has_many :addresses, dependent: :destroy, class_name: 'BetterTogether::Address'
    has_many :social_media_accounts, dependent: :destroy, class_name: 'BetterTogether::SocialMediaAccount'
    has_many :website_links, dependent: :destroy, class_name: 'BetterTogether::WebsiteLink'

    accepts_nested_attributes_for :phone_numbers, :email_addresses,
                                  :addresses, :social_media_accounts, :website_links,
                                  allow_destroy: true,
                                  reject_if: :all_blank

    def self.permitted_attributes(id: false, destroy: false, exclude_extra: false)
      [
        :name, :role,
        {
          phone_numbers_attributes: [:id, :number, :_destroy, *PhoneNumber.extra_permitted_attributes],
          email_addresses_attributes: [:id, :email, :_destroy, *EmailAddress.extra_permitted_attributes],
          social_media_accounts_attributes: [:id, :platform, :handle, :url, :_destroy,
                                             *SocialMediaAccount.extra_permitted_attributes],
          addresses_attributes: [:id, :physical, :postal, :line1, :line2, :city_name, :state_province_name,
                                 :postal_code, :country_name, :_destroy, *Address.extra_permitted_attributes],
          website_links_attributes: [:id, :url, :_destroy, *WebsiteLink.extra_permitted_attributes]
        }
      ] + super
    end

    def has_contact_details? # rubocop:todo Naming/PredicateName
      # rubocop:todo Layout/LineLength
      phone_numbers.size.positive? || email_addresses.size.positive? || addresses.size.positive? || social_media_accounts.size.positive? || website_links.size.positive?
      # rubocop:enable Layout/LineLength
    end

    def person
      super || build_person
    end
  end
end
