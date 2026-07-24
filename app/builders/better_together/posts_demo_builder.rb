# frozen_string_literal: true

# app/builders/better_together/posts_demo_builder.rb

module BetterTogether
  # Seeds a representative demo dataset for Posts to QA the sidebar filters.
  class PostsDemoBuilder < Builder # rubocop:todo Metrics/ClassLength
    DEMO_TAG = '[Demo]'
    DEMO_IDENTIFIER_PREFIX = 'demo-post'

    CATEGORY_SEEDS = [
      {
        identifier: 'post-community-updates',
        name: 'Community Updates',
        description: 'Platform announcements, milestones, and governance notes.'
      },
      {
        identifier: 'post-learning-guides',
        name: 'Learning & Guides',
        description: 'How-to content, onboarding, and practical tips.'
      },
      {
        identifier: 'post-safety-wellbeing',
        name: 'Safety & Wellbeing',
        description: 'Safety reminders, support resources, and wellbeing tips.'
      },
      {
        identifier: 'post-events',
        name: 'Events & Gatherings',
        description: 'Recaps and upcoming event details.'
      },
      {
        identifier: 'post-community-resources',
        name: 'Community Resources',
        description: 'Links, services, and shared community resources.'
      }
    ].freeze
    DEMO_POST_INCREMENT = 50

    class << self
      def seed_data
        raise 'FactoryBot is required to build demo posts.' unless defined?(FactoryBot)

        I18n.with_locale(:en) do
          categories = ensure_post_categories!
          people = build_people
          build_posts(people:, categories:)
        end
      end

      def clear_existing
        demo_posts.find_each(&:destroy)
      end

      private

      def ensure_post_categories!
        CATEGORY_SEEDS.map do |attrs|
          category = ::BetterTogether::Category.find_or_create_by!(identifier: attrs[:identifier]) do |record|
            record.name_en = attrs[:name]
            record.description_en = attrs[:description]
          end
          next category if category.name_en.present?

          category.update!(name_en: attrs[:name], description_en: attrs[:description])
          category
        end
      end

      def build_people
        names = [
          'Ava Patel', 'Liam Nguyen', 'Maya Chen', 'Noah Garcia',
          'Sophia Ahmed', 'Ethan Rossi', 'Zoe Kim', 'Oliver Dubois'
        ]

        names.map do |name|
          ::BetterTogether::Person.find_or_create_by!(identifier: identifier_for(name)) do |person|
            person.name = name
          end
        end
      end

      # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      def build_posts(people:, categories:)
        cat = ->(identifier) { categories.find { |category| category.identifier == identifier } }

        data = [
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-community-garden-kickoff",
            title: "#{DEMO_TAG} Community garden kickoff",
            content: 'Join the kickoff and learn how to reserve plots. Includes volunteer roles and water access info.',
            privacy: 'public',
            published_at: 10.days.ago,
            categories: [cat.call('post-community-updates'), cat.call('post-events')],
            author: people.first
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-newcomer-guide-local-services",
            title: "#{DEMO_TAG} Newcomer guide: local services",
            content: 'A quick guide to transit, health clinics, and newcomer support contacts.',
            privacy: 'community',
            published_at: 7.days.ago,
            categories: [cat.call('post-learning-guides'), cat.call('post-community-resources')],
            author: people.second
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-safety-checkin-heat-tips",
            title: "#{DEMO_TAG} Safety check-in and heat tips",
            content: 'Heatwave readiness checklist, cooling centers, and buddy system reminders.',
            privacy: 'public',
            published_at: 5.days.ago,
            categories: [cat.call('post-safety-wellbeing')],
            author: people.third
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-volunteer-appreciation-recap",
            title: "#{DEMO_TAG} Volunteer appreciation recap",
            content: 'Highlights from last week and a short list of upcoming volunteer shifts.',
            privacy: 'community',
            published_at: 3.days.ago,
            categories: [cat.call('post-community-updates')],
            author: people.fourth
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-workshop-notes-skill-sharing",
            title: "#{DEMO_TAG} Workshop notes: skill sharing",
            content: 'Summary of the skill share workshop with links to materials and follow-up dates.',
            privacy: 'private',
            published_at: 2.days.ago,
            categories: [cat.call('post-learning-guides')],
            author: people.fifth
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-resource-roundup-mutual-aid",
            title: "#{DEMO_TAG} Resource roundup for mutual aid",
            content: 'Updated list of resources, donation drop-offs, and language support lines.',
            privacy: 'public',
            published_at: 1.day.ago,
            categories: [cat.call('post-community-resources')],
            author: people[5]
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-upcoming-community-meetup",
            title: "#{DEMO_TAG} Upcoming community meetup",
            content: 'Agenda preview, accessibility notes, and RSVP instructions.',
            privacy: 'community',
            published_at: 6.hours.ago,
            categories: [cat.call('post-events')],
            author: people[6]
          },
          {
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-draft-quiet-hours-proposal",
            title: "#{DEMO_TAG} Draft: quiet hours proposal",
            content: 'Early draft for feedback: proposed quiet hours and escalation contacts.',
            privacy: 'private',
            published_at: nil,
            categories: [cat.call('post-community-updates'), cat.call('post-safety-wellbeing')],
            author: people.first
          }
        ]

        data.each do |row|
          ::BetterTogether::Post.find_or_create_by!(identifier: row[:identifier]) do |post|
            post.title = row[:title]
            post.content = row[:content]
            post.privacy = row[:privacy]
            post.published_at = row[:published_at]
            post.categories = row[:categories].compact
            post.author = row[:author]
          end
        end

        existing_generated = demo_posts
                             .where(demo_identifier_match("#{DEMO_IDENTIFIER_PREFIX}-generated-%"))
                             .count
        start_index = existing_generated + 1
        privacy_cycle = %w[public community private]

        DEMO_POST_INCREMENT.times do |offset|
          count = start_index + offset
          FactoryBot.create(
            :better_together_post,
            identifier: "#{DEMO_IDENTIFIER_PREFIX}-generated-#{count}",
            title: "#{DEMO_TAG} Community update #{count}",
            content: "Additional demo post #{count} for pagination testing.",
            privacy: privacy_cycle[count % privacy_cycle.length],
            published_at: ((count % 7).zero? ? nil : (count + 1).days.ago),
            categories: [categories[count % categories.length]],
            author: people[count % people.length]
          )
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def demo_posts
        ::BetterTogether::Post.where(demo_identifier_match("#{DEMO_IDENTIFIER_PREFIX}-%"))
      end

      def demo_identifier_match(pattern)
        ::BetterTogether::Post.arel_table[:identifier].matches(pattern)
      end

      def identifier_for(name)
        "#{DEMO_TAG} #{name}".parameterize
      end
    end
  end
end
