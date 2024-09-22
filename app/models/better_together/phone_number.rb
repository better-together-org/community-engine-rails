module BetterTogether
  class PhoneNumber < ApplicationRecord
    include PrimaryFlag
    include Privacy

    primary_flag_scope :contact_detail_id

    # Define the available labels for phone numbers
    LABELS = [:mobile, :home, :work, :fax, :other].freeze
    include Labelable

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail'

    # Validations
    validates :number, presence: true
  end
end
