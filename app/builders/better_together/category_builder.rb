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
            { name_en: 'Accommodation',  position: 0 },
            { name_en: 'Transportation', position: 1 },
            { name_en: 'Childcare',      position: 2 },
            { name_en: 'Food',           position: 3 },
            { name_en: 'Translation',    position: 4 },
            { name_en: 'Other',          position: 5 }
          ]
        )
      end

      # Remove existing categories
      def clear_existing
        ::BetterTogether::Category.delete_all
      end
    end
  end
end
