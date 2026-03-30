# frozen_string_literal: true

module BetterTogether
  module Metrics
    class Share < ApplicationRecord # rubocop:todo Style/Documentation
      SHAREABLE_PLATFORMS = %w[email facebook bluesky linkedin pinterest reddit whatsapp].freeze

      # Associations
      belongs_to :tenant_platform, class_name: 'BetterTogether::Platform', foreign_key: :platform_id
      belongs_to :shareable, polymorphic: true, optional: true

      scope :for_platform, ->(platform) { where(platform_id: platform.id) }

      # Validations
      validates :platform, presence: true, inclusion: { in: SHAREABLE_PLATFORMS }
      validates :url, presence: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
      validates :shared_at, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
      validates :logged_in, inclusion: { in: [true, false] }
    end
  end
end
