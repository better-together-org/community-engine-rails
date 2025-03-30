# frozen_string_literal: true

module BetterTogether
  class SocialMediaAccount < ApplicationRecord # rubocop:todo Style/Documentation
    include Privacy

    belongs_to :contact_detail, class_name: 'BetterTogether::ContactDetail', touch: true

    # Enumerations for platforms
    PLATFORMS = %w[Facebook Instagram X LinkedIn YouTube TikTok Reddit What'sApp].freeze

    URL_TEMPLATES = {
      'Facebook' => 'https://www.facebook.com/%<handle>s',
      'Instagram' => 'https://www.instagram.com/%<handle>s',
      'Bluesky' => 'https://bsky.app/profile/%<handle>s',
      'LinkedIn' => 'https://www.linkedin.com/in/%<handle>s',
      'YouTube' => 'https://www.youtube.com/%<handle>s',
      'TikTok' => 'https://www.tiktok.com/@%<handle>s',
      'Reddit' => 'https://www.reddit.com/user/%<handle>s'
      # 'WhatsApp' does not have a URL template
    }.freeze

    # Validations
    validates :platform, presence: true, inclusion: { in: PLATFORMS }
    validates :handle, presence: true
    validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
    validates :platform,
              uniqueness: { scope: :contact_detail_id, message: 'account already exists for this contact detail' }

    before_validation :generate_url, if: -> { handle_changed? || platform_changed? || url.blank? }

    def to_s
      "#{platform}: #{handle}"
    end

    private

    def generate_url
      template = URL_TEMPLATES[platform]
      if template
        formatted_handle = sanitize_handle(handle)
        self.url = format(template, handle: formatted_handle)
      else
        self.url = nil
      end
    end

    def sanitize_handle(raw_handle)
      # Remove leading '@' if present
      raw_handle.to_s.strip.sub(/\A@/, '').parameterize
    end
  end
end
