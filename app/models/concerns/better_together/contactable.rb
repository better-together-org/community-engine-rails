# frozen_string_literal: true

module BetterTogether
  module Contactable # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      has_one :contact_detail, as: :contactable, dependent: :destroy, class_name: 'BetterTogether::ContactDetail'
      accepts_nested_attributes_for :contact_detail, allow_destroy: true

      delegate :has_contact_details?, to: :contact_detail, allow_nil: true

      # has_many :through associations for each contact type
      has_many :phone_numbers, through: :contact_detail, source: :phone_numbers
      has_many :email_addresses, through: :contact_detail, source: :email_addresses
      has_many :social_media_accounts, through: :contact_detail, source: :social_media_accounts
      has_many :addresses, through: :contact_detail, source: :addresses
      has_many :postal_addresses, -> { where(postal: true) }, through: :contact_detail, source: :addresses
      has_many :physical_addresses, -> { where(physical: true) }, through: :contact_detail, source: :addresses
      has_many :website_links, through: :contact_detail, source: :website_links

      before_validation :build_default_contact_details, if: :new_record?
      before_validation :create_contact_detail, if: -> { persisted? && contact_detail.nil? }
    end

    class_methods do
      def extra_permitted_attributes # rubocop:todo Metrics/MethodLength
        super + [
          contact_detail_attributes: [
            :id, :_destroy,
            { phone_numbers_attributes: [:id, :number, :_destroy, *PhoneNumber.extra_permitted_attributes],
              email_addresses_attributes: [:id, :email, :_destroy, *EmailAddress.extra_permitted_attributes],
              social_media_accounts_attributes: [:id, :platform, :handle, :url, :_destroy,
                                                 *SocialMediaAccount.extra_permitted_attributes],
              addresses_attributes: [:id, :physical, :postal, :line1, :line2, :city_name, :state_province_name,
                                     :postal_code, :country_name, :_destroy, *Address.extra_permitted_attributes],
              website_links_attributes: [:id, :url, :_destroy, *WebsiteLink.extra_permitted_attributes] }
          ]
        ]
      end
    end

    private

    def build_default_contact_details
      return if contact_detail.present?

      build_contact_detail
    end

    def create_contact_detail
      return if contact_detail.present? || new_record?

      super
    end
  end
end
