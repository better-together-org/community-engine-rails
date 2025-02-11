# frozen_string_literal: true

module BetterTogether
  class WebsiteLink < ApplicationRecord # rubocop:todo Style/Documentation
    include Privacy

    LABELS = %i[
      personal_website blog portfolio resume company_website community_page
      product_page services support contact_us about_us events donations careers
      privacy_policy terms_of_service faq forum documentation newsletter other
    ].freeze
    include Labelable

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail', touch: true

    # Validations
    validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  end
end
