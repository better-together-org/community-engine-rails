# frozen_string_literal: true

# app/builders/better_together/category_builder.rb
module BetterTogether
  # Builder to create initial event and Joatu categories
  class CategoryBuilder < Builder
    class << self
      # Seed default categories for events and Joatu offers/requests
      def seed_data
        I18n.with_locale(:en) do
          build_event_categories
          build_joatu_categories
        end
      end

      # Define event categories
      def build_event_categories
        ::BetterTogether::EventCategory.create!(
          [
            { name_en: 'Conference', position: 0 },
            { name_en: 'Meetup',      position: 1 },
            { name_en: 'Workshop',    position: 2 },
            { name_en: 'Webinar',     position: 3 }
          ]
        )
      end

      # Define Joatu offer/request categories
      def build_joatu_categories
        ::BetterTogether::Joatu::Category.create!(
          [
            { name_en: 'Accommodation' },
            { name_en: 'Childcare' },
            { name_en: 'Cleanup & Repairs' },
            { name_en: 'Emergency Supplies' },
            { name_en: 'Evacuation Housing' },
            { name_en: 'Food & Water' },
            { name_en: 'Medical Assistance' },
            { name_en: 'Other' },
            { name_en: 'Pet Care' },
            { name_en: 'Platform Invitations' }, # Added for internal/platform-related offers
            { name_en: 'Translation' },
            { name_en: 'Transportation' },
            { name_en: 'Volunteers' }
          ]
          .sort_by { |attrs| attrs[:name_en] }
          .each_with_index
          .map { |attrs, idx| attrs.merge(position: idx) }
        )
      end

      # Remove existing categories
      def clear_existing
        ::BetterTogether::Category.delete_all
      end
    end
  end
end
