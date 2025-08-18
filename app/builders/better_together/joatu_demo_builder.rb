# frozen_string_literal: true

# app/builders/better_together/joatu_demo_builder.rb

module BetterTogether
  # Seeds a realistic demo dataset for the Joatu exchange system
  class JoatuDemoBuilder < Builder # rubocop:todo Metrics/ClassLength
    DEMO_TAG = '[Demo]'

    class << self
      def seed_data
        I18n.with_locale(:en) do
          ensure_categories!

          people = build_people
          community = build_demo_community(creator: people.first)

          addresses = build_addresses

          requests = build_requests(people:, community:, addresses:)
          offers   = build_offers(people:, community:, addresses:)

          build_agreements(requests:, offers:)
        end
      end

      # Cautious clean-up: only removes demo-tagged data created by this builder
      # rubocop:todo Metrics/MethodLength
      def clear_existing # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Agreements first due to FK
        ::BetterTogether::Joatu::Agreement
          .joins(:offer)
          .where("#{::BetterTogether::Joatu::Offer.table_name}.id IN (?)",
                 demo_offers.select(:id))
          .delete_all

        ::BetterTogether::Joatu::Agreement
          .joins(:request)
          .where("#{::BetterTogether::Joatu::Request.table_name}.id IN (?)",
                 demo_requests.select(:id))
          .delete_all

        demo_offers.delete_all
        demo_requests.delete_all

        demo_community&.destroy
        demo_people.delete_all
      end
      # rubocop:enable Metrics/MethodLength

      private

      # -- Core builders --

      def ensure_categories!
        return if ::BetterTogether::Joatu::Category.exists?

        ::BetterTogether::CategoryBuilder.seed_data
      end

      def build_people
        names = [
          'Ava Patel', 'Liam Nguyen', 'Maya Chen', 'Noah Garcia',
          'Sophia Ahmed', 'Ethan Rossi', 'Zoe Kim', 'Oliver Dubois'
        ]

        names.map do |name|
          ::BetterTogether::Person.find_or_create_by!(identifier: identifier_for(name)) do |p|
            p.name = name
          end
        end
      end

      def build_demo_community(creator:)
        ::BetterTogether::Community.find_or_create_by!(identifier: 'joatu-demo') do |c|
          c.name_en = 'Joatu Demo Community'
          c.description_en = 'A sample community to scope Joatu exchanges.'
          c.creator = creator
          c.privacy = 'public'
        end
      end

      def build_addresses
        [
          { line1: '123 Harbour Rd',   city_name: 'St. John\'s', state_province_name: 'NL', postal_code: 'A1A 1A1' },
          { line1: '42 Elm Street',    city_name: 'Halifax',      state_province_name: 'NS', postal_code: 'B3H 2Y9' },
          { line1: '77 Maple Avenue',  city_name: 'Montreal',     state_province_name: 'QC', postal_code: 'H2X 3V9' },
          { line1: '900 King Street',  city_name: 'Toronto',      state_province_name: 'ON', postal_code: 'M5V 1G4' },
          { line1: '12 Oak Crescent',  city_name: 'Calgary',      state_province_name: 'AB', postal_code: 'T2P 3N9' }
        ].map do |attrs|
          ::BetterTogether::Address.create!(attrs.merge(physical: true, postal: false, country_name: 'Canada'))
        end
      end

      # rubocop:todo Metrics/AbcSize
      def build_requests(people:, community:, addresses:) # rubocop:todo Metrics/MethodLength
        cat = ->(name) { find_category(name) }

        data = [
          {
            name: 'Home-cooked meals for seniors',
            desc: 'Requesting daily dinners for two seniors recovering post-surgery.',
            categories: [cat.call('Food & Water')],
            urgency: 'high'
          },
          {
            name: 'School pickup for two kids',
            desc: 'Help needed for weekday school pickup for 2 children.',
            categories: [cat.call('Childcare'), cat.call('Transportation')],
            urgency: 'normal'
          },
          {
            name: 'Minor roof repair post-storm',
            desc: 'Shingles lifted in last storm; need minor roof patch.',
            categories: [cat.call('Cleanup & Repairs')],
            urgency: 'critical'
          },
          {
            name: 'Spanish translation for clinic visit',
            desc: 'Looking for Spanish interpretation for a medical appointment.',
            categories: [cat.call('Translation'), cat.call('Medical Assistance')],
            urgency: 'high'
          },
          {
            name: 'Temporary housing for 3 nights',
            desc: 'Family of 3 needs a place to stay after flooding.',
            categories: [cat.call('Evacuation Housing'), cat.call('Accommodation')],
            urgency: 'high'
          }
        ]

        data.map.with_index do |row, i|
          ::BetterTogether::Joatu::Request.create!(
            name_en: "#{DEMO_TAG} #{row[:name]}",
            description_en: row[:desc],
            creator: people.sample,
            categories: row[:categories].compact,
            status: 'open',
            urgency: row[:urgency],
            address: addresses[i % addresses.size],
            target: community
          )
        end
      end
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/AbcSize
      def build_offers(people:, community:, addresses:) # rubocop:todo Metrics/MethodLength
        cat = ->(name) { find_category(name) }

        data = [
          {
            name: 'Batch-cooked meals available',
            desc: 'Cooking extra dinners this week; can deliver locally.',
            categories: [cat.call('Food & Water')],
            urgency: 'normal'
          },
          {
            name: 'Evening rides with minivan',
            desc: 'Offering weekday evening rides; car seats available.',
            categories: [cat.call('Transportation')],
            urgency: 'low'
          },
          {
            name: 'Handyman for minor repairs',
            desc: 'Experienced with basic home repairs; evenings/weekends.',
            categories: [cat.call('Cleanup & Repairs')],
            urgency: 'normal'
          },
          {
            name: 'Bilingual Spanish interpreter',
            desc: 'Fluent in Spanish and English; can accompany to appointments.',
            categories: [cat.call('Translation')],
            urgency: 'normal'
          },
          {
            name: 'Guest room available',
            desc: 'Quiet room with private bath for short-term stays.',
            categories: [cat.call('Accommodation'), cat.call('Evacuation Housing')],
            urgency: 'high'
          }
        ]

        data.map.with_index do |row, i|
          ::BetterTogether::Joatu::Offer.create!(
            name_en: "#{DEMO_TAG} #{row[:name]}",
            description_en: row[:desc],
            creator: people.sample,
            categories: row[:categories].compact,
            status: 'open',
            urgency: row[:urgency],
            address: addresses[(i + 2) % addresses.size],
            target: community
          )
        end
      end
      # rubocop:enable Metrics/AbcSize

      # rubocop:todo Metrics/MethodLength
      def build_agreements(requests:, offers:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Try to pair similar categories for realism
        pair = lambda do |req_name_contains:, off_name_contains:, status: :pending, terms: nil, value: nil|
          req = requests.find { |r| r.name.include?(req_name_contains) }
          off = offers.find { |o| o.name.include?(off_name_contains) }
          return unless req && off

          agr = ::BetterTogether::Joatu::Agreement.create!(
            offer: off,
            request: req,
            terms: terms,
            value: value,
            status: 'pending'
          )

          case status
          when :accepted
            agr.accept!
          when :rejected
            agr.reject!
          end
        end

        pair.call(
          req_name_contains: 'meals',
          off_name_contains: 'meals',
          status: :accepted,
          terms: 'Deliver dinners Mon–Fri for 1 week',
          value: '6 credits'
        )

        pair.call(
          req_name_contains: 'School pickup',
          off_name_contains: 'rides',
          status: :pending,
          terms: 'Pickup at 3pm, Mon–Thu',
          value: 'fuel cost only'
        )

        pair.call(
          req_name_contains: 'roof repair',
          off_name_contains: 'Handyman',
          status: :accepted,
          terms: 'Patch shingles and inspect attic',
          value: 'no cost'
        )

        pair.call(
          req_name_contains: 'Temporary housing',
          off_name_contains: 'Guest room',
          status: :rejected,
          terms: '3 nights, no pets',
          value: 'n/a'
        )
      end
      # rubocop:enable Metrics/MethodLength

      # -- Helpers --

      def find_category(name)
        ::BetterTogether::Joatu::Category.i18n.find_by(name: name)
      end

      def identifier_for(name)
        "#{DEMO_TAG} #{name}".parameterize
      end

      def demo_people
        ::BetterTogether::Person.where('identifier LIKE ?', "#{DEMO_TAG.downcase.tr('[]', '')}%")
      end

      def demo_community
        ::BetterTogether::Community.find_by(identifier: 'joatu-demo')
      end

      def demo_offers
        ::BetterTogether::Joatu::Offer.i18n.where('mobility_string_translations.value LIKE ?', "%#{DEMO_TAG}%")
      end

      def demo_requests
        ::BetterTogether::Joatu::Request.i18n.where('mobility_string_translations.value LIKE ?', "%#{DEMO_TAG}%")
      end
    end
  end
end
