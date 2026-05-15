# frozen_string_literal: true

module BetterTogether
  class ShortLink < ApplicationRecord # rubocop:todo Style/Documentation
    include PlatformScoped
    include Creatable
    include Translatable

    translates :title, type: :string

    CODE_ALPHABET = (('a'..'z').to_a + ('0'..'9').to_a).freeze
    CODE_LENGTH   = 6

    def self.extra_permitted_attributes
      super + %i[code target_url status expires_at linkable_type linkable_id]
    end

    has_many :short_link_visits,
             class_name: 'BetterTogether::Metrics::ShortLinkVisit',
             dependent: :destroy

    belongs_to :linkable, polymorphic: true, optional: true

    enum :status, { active: 'active', inactive: 'inactive', expired: 'expired' }, prefix: :status

    validates :code,       presence: true,
                           uniqueness: { scope: :platform_id, case_sensitive: false },
                           format: { with: /\A[a-z0-9-]+\z/ }
    validates :target_url, presence: true
    validate  :target_url_scheme_valid

    before_validation :ensure_code_present
    before_save       :auto_expire_if_past

    def url
      "#{platform.share_base_url}/s/#{code}"
    end

    def active_and_unexpired?
      status_active? && !past_expiry?
    end

    private

    def past_expiry?
      expires_at.present? && expires_at < Time.current
    end

    def ensure_code_present
      return if code.present?

      loop do
        candidate = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample }.join
        self.code = candidate
        break unless self.class.where(platform:).exists?(code: candidate)
      end
    end

    def auto_expire_if_past
      self.status = 'expired' if past_expiry? && !status_expired?
    end

    def target_url_scheme_valid
      uri = URI.parse(target_url.to_s)
      errors.add(:target_url, :invalid_scheme) unless %w[http https].include?(uri.scheme)
    rescue URI::InvalidURIError
      errors.add(:target_url, :invalid)
    end
  end
end
