
module BetterTogether
  class EmailAddress < ApplicationRecord
    include Privacy

    LABELS = [:personal, :work, :school, :other].freeze
    include Labelable

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail'

    # Validations
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
