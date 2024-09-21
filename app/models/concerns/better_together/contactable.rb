
module BetterTogether
  module Contactable
    extend ActiveSupport::Concern

    included do
      has_one :contact_detail, as: :contactable, dependent: :destroy, class_name: 'BetterTogether::ContactDetail'
      accepts_nested_attributes_for :contact_detail, allow_destroy: true

      # has_many :through associations for each contact type
      has_many :phone_numbers, through: :contact_detail, source: :phone_numbers
      has_many :email_addresses, through: :contact_detail, source: :email_addresses
      has_many :social_media_accounts, through: :contact_detail, source: :social_media_accounts
      has_many :addresses, through: :contact_detail, source: :addresses
      has_many :postal_addresses, -> { where(postal: true) }, through: :contact_detail, source: :addresses
      has_many :physical_addresses, -> { where(physical: true) }, through: :contact_detail, source: :addresses

      after_initialize :build_default_contact_details, if: :new_record?
      after_initialize :create_contact_detail, if: -> { persisted? && contact_detail.nil? }
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          contact_detail_attributes: [
            :id, :_destroy,
            phone_numbers_attributes: [:id, :label, :privacy, :number, :_destroy],
            email_addresses_attributes: [:id, :label, :privacy, :email, :_destroy],
            social_media_accounts_attributes: [:id, :platform, :privacy, :handle, :url, :_destroy],
            addresses_attributes: [:id, :label, :privacy, :physical, :postal, :line1, :line2, :city_name, :state_province_name, :postal_code, :country_name, :_destroy]
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
