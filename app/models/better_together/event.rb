# frozen_string_literal: true

module BetterTogether
  # A Schedulable Event
  class Event < ApplicationRecord
    include Attachments::Images
    include Categorizable
    include Creatable
    include FriendlySlug
    include Geography::Geospatial::One
    include Geography::Locatable::One
    include Identifier
    include Privacy
    include TrackedActivity
    include Viewable

    attachable_cover_image

    categorizable(class_name: 'BetterTogether::EventCategory')

    # belongs_to :address, -> { where(physical: true, primary_flag: true) }
    # accepts_nested_attributes_for :address, allow_destroy: true, reject_if: :blank?
    # delegate :geocoding_string, to: :address, allow_nil: true
    # geocoded_by :geocoding_string

    translates :name
    translates :description, backend: :action_text

    validates :name, presence: true
    validates :registration_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true,
                                 allow_nil: true

    scope :draft, lambda {
      start_query = arel_table[:starts_at].eq(nil)
      where(start_query)
    }

    scope :upcoming, lambda {
      start_query = arel_table[:starts_at].gteq(Time.current)
      where(start_query)
    }

    scope :past, lambda {
      start_query = arel_table[:starts_at].lt(Time.current)
      where(start_query)
    }

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        starts_at ends_at registration_url
      ] + [
        {
          address_attributes: BetterTogether::Address.permitted_attributes(id: true)
        }
      ]
    end

    def schedule_address_geocoding
      return unless should_geocode?

      BetterTogether::Geography::GeocodingJob.perform_later(self)
    end

    def should_geocode?
      return false if geocoding_string.blank?

      # space.reload # in case it has been geocoded since last load

      (address_changed? or !geocoded?)
    end

    def to_s
      name
    end

    configure_attachment_cleanup
  end
end
