# frozen_string_literal: true

module BetterTogether
  module Contactable # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      has_one :contact_detail, as: :contactable, dependent: :destroy, class_name: 'BetterTogether::ContactDetail'
      has_many :contacts, as: :contactable, dependent: :destroy, class_name: 'BetterTogether::ContactDetail'
      accepts_nested_attributes_for :contact_detail, :contacts, reject_if: :all_blank

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
      def extra_permitted_attributes
        super + [
          contact_detail_attributes: BetterTogether::ContactDetail.permitted_attributes(id: true, destroy: true),
          contacts_attributes: BetterTogether::ContactDetail.permitted_attributes(id: true, destroy: true)
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
