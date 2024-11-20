module BetterTogether
  class ContactDetail < ApplicationRecord
    belongs_to :contactable, polymorphic: true, touch: true

    has_many :phone_numbers, dependent: :destroy, class_name: 'BetterTogether::PhoneNumber'
    has_many :email_addresses, dependent: :destroy, class_name: 'BetterTogether::EmailAddress'
    has_many :addresses, dependent: :destroy, class_name: 'BetterTogether::Address'
    has_many :social_media_accounts, dependent: :destroy, class_name: 'BetterTogether::SocialMediaAccount'
    has_many :website_links, dependent: :destroy, class_name: 'BetterTogether::WebsiteLink'

    accepts_nested_attributes_for :phone_numbers, allow_destroy: true
    accepts_nested_attributes_for :email_addresses, allow_destroy: true
    accepts_nested_attributes_for :addresses, allow_destroy: true
    accepts_nested_attributes_for :social_media_accounts, allow_destroy: true
    accepts_nested_attributes_for :website_links, allow_destroy: true

    def has_contact_details?
      phone_numbers.size > 0 || email_addresses.size > 0 || addresses.size > 0 || social_media_accounts.size > 0 || website_links.size > 0
    end
  end
end
