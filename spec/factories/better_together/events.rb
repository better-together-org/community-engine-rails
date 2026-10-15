# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/event',
          class: 'BetterTogether::Event',
          aliases: %i[better_together_event event] do
    # Remove manual ID setting - let Rails handle this
    identifier { Faker::Internet.unique.uuid }
    name { Faker::Lorem.unique.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    starts_at { 1.week.from_now }
    ends_at { 1.week.from_now + 2.hours }
    registration_url { Faker::Internet.url }
    privacy { 'public' }
    # DB default is 'draft' (explicit publish step); the factory represents a
    # published event, so confirm it unless a spec overrides status.
    status { 'confirmed' }
    timezone { 'America/New_York' }

    association :creator, factory: :person

    # Assign platform after build so Shoulda matchers (which call save(validate: false)
    # and skip before_validation callbacks) don't hit the NOT NULL DB constraint.
    # Note: before(:build) fires with nil as the object in factory_bot 6.5+;
    # after(:build) fires with the actual built instance.
    after(:build) do |event|
      unless event.platform_id.present?
        event.platform = Current.platform ||
                         BetterTogether::Platform.find_by(host: true)
      end
    end

    before(:create) do |event|
      unless event.platform_id.present?
        event.platform = Current.platform ||
                         BetterTogether::Platform.find_by(host: true) ||
                         create(:better_together_platform)
      end
    end

    trait :with_simple_location do
      after(:build) do |event|
        event.location = build(:locatable_location, :simple, locatable: event)
      end
    end

    trait :with_address_location do
      after(:build) do |event|
        event.location = build(:locatable_location, :with_address, locatable: event)
      end
    end

    trait :with_building_location do
      after(:build) do |event|
        event.location = build(:locatable_location, :with_building, locatable: event)
      end
    end

    trait :draft do
      status { 'draft' }
      starts_at { nil }
      ends_at { nil }
    end

    trait :past do
      starts_at { 1.week.ago }
      ends_at { 1.week.ago + 2.hours }
    end

    trait :upcoming do
      starts_at { 1.week.from_now }
      ends_at { 1.week.from_now + 2.hours }
    end

    trait :with_attendees do
      after(:create) do |event|
        create_list(:event_attendance, 3, event: event)
      end
    end

    # Reproduces the 2026-09 production incident: a rich text body
    # non-idempotently re-wrapped in its own render output on repeated
    # read-then-save round trips (`ActionText::Content#to_s` always adds one
    # more `<div class="trix-content">` layer). Written directly to the
    # column so the wrapper count is exact and isn't touched by ActionText's
    # normal save-path sanitization.
    trait :with_pathologically_wrapped_description do
      transient do
        wrapper_repeats { 400 }
      end

      after(:create) do |event, evaluator|
        open_wrapper = '<div class="trix-content">' * evaluator.wrapper_repeats
        close_wrapper = '</div>' * evaluator.wrapper_repeats
        wrapped = "#{open_wrapper}<p>Original event description.</p>#{close_wrapper}"
        BetterTogether::TestSupport::RawRichText.write!(event, :description, wrapped)
        # #reset (not #reload) -- just drops the has_one cache so the next
        # access re-queries fresh. #reload would re-query AND immediately use
        # the freshly loaded target, and something in that path calls .nil?
        # on it -- which is itself dangerous on pathological content, since
        # ActionText::RichText delegates #nil? to #body. See RawRichText.
        event.association(:rich_text_description).reset
      end
    end
  end
end
