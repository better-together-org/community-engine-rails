module BetterTogether
  class PhoneNumber < ApplicationRecord
    include Privacy

    # Define the available labels for phone numbers
    LABELS = [:mobile, :home, :work, :fax, :other].freeze
    include Labelable

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail'

    # Validations
    validates :number, presence: true
  end
end
