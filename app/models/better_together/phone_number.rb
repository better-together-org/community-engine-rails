# frozen_string_literal: true

module BetterTogether
  class PhoneNumber < ApplicationRecord # rubocop:todo Style/Documentation
    include PrimaryFlag
    include Privacy

    primary_flag_scope :contact_detail_id

    # Define the available labels for phone numbers
    LABELS = %i[mobile home work fax other].freeze
    include Labelable

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail', touch: true

    # Validations
    validates :number, presence: true
  end
end
