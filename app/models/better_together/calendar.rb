# frozen_string_literal: true

module BetterTogether
  # Calendar management and display
  class Calendar < ApplicationRecord
    include Creatable
    include FriendlySlug
    include Identifier
    include Privacy
    include Protected
    include Viewable

    belongs_to :community, class_name: '::BetterTogether::Community'

    has_many :calendar_entries, class_name: 'BetterTogether::CalendarEntry', dependent: :destroy
    has_many :events, through: :calendar_entries

    slugged :name

    translates :name, type: :string
    translates :description, backend: :action_text

    validates :subscription_token, uniqueness: true, allow_nil: true

    before_create :generate_subscription_token

    def to_s
      name
    end

    def regenerate_subscription_token!
      update!(subscription_token: SecureRandom.uuid)
    end

    private

    def generate_subscription_token
      self.subscription_token ||= SecureRandom.uuid
    end
  end
end
