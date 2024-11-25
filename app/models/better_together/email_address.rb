# frozen_string_literal: true

module BetterTogether
  class EmailAddress < ApplicationRecord
    include PrimaryFlag
    include Privacy

    primary_flag_scope :contact_detail_id

    LABELS = %i[personal work school other].freeze
    include Labelable

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail', touch: true

    # Validations
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
