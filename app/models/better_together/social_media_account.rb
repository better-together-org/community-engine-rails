module BetterTogether
  class SocialMediaAccount < ApplicationRecord
    include Privacy

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail'

    # Enumerations for platforms
    PLATFORMS = %w[Facebook Instagram X LinkedIn YouTube TikTok Reddit What'sApp]

    # Validations
    validates :platform, presence: true, inclusion: { in: PLATFORMS }
    validates :handle, presence: true
    validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
    validates :platform, uniqueness: { scope: :contact_detail_id, message: "account already exists for this contact detail" }
  end
end
