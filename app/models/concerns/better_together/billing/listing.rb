# frozen_string_literal: true

module BetterTogether
  module Billing
    # Whether something sold is on offer and who may see and buy it: switched on or off, shown in the public catalog
    # or not, and optionally limited to members or subscribers of the platform (see Plans::Audience). Needs the columns
    # `active`, `listed`, `restricted_to_members` and `restricted_to_subscribers`. Shared by every sellable kind.
    module Listing
      extend ActiveSupport::Concern

      included do
        validates :active, inclusion: { in: [true, false] }

        scope :active, -> { where(active: true) }
        # What the public catalog shows: bought-able things a steward chose to list.
        scope :listed, -> { active.where(listed: true) }
        scope :unrestricted, -> { where(restricted_to_members: false, restricted_to_subscribers: false) }

        # What a person may see and buy, given what they are to the platform (see Plans::Audience): the unrestricted ones, and
        # each limited one they qualify for. Any one qualification is enough.
        scope :open_to, lambda { |audience|
          open = unrestricted
          open = open.or(where(restricted_to_members: true)) if audience.member
          open = open.or(where(restricted_to_subscribers: true)) if audience.subscriber
          open
        }
      end

      def restricted? = restricted_to_members || restricted_to_subscribers

      # Whether someone with this audience (see Plans::Audience) qualifies: anyone does if it is not limited, else any one kind.
      def open_to?(audience)
        return true unless restricted?

        (restricted_to_members && audience.member) || (restricted_to_subscribers && audience.subscriber) || false
      end
    end
  end
end
