# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_content_image, class: 'BetterTogether::Content::Image' do
    association :creator, factory: :better_together_person
    privacy { 'public' }
    identifier { "image-block-#{SecureRandom.hex(4)}" }
    attribution { Faker::Name.name }
    alt_text { Faker::Lorem.sentence(word_count: 3) }
    caption { Faker::Lorem.sentence }
    attribution_url { Faker::Internet.url }

    after(:build) do |image|
      next if image.media.attached?

      # Create a minimal valid 1x1 PNG image in memory
      # rubocop:todo Layout/LineLength
      png_data = "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
      # rubocop:enable Layout/LineLength
      image.media.attach(
        io: StringIO.new(png_data),
        filename: 'test-image.png',
        content_type: 'image/png'
      )
    end

    trait :with_jpg do
      after(:build) do |image|
        image.media.purge if image.media.attached?
        image.media.attach(
          io: StringIO.new("fake jpg content #{SecureRandom.hex}"),
          filename: 'test-image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    trait :with_gif do
      after(:build) do |image|
        image.media.purge if image.media.attached?
        image.media.attach(
          io: StringIO.new("fake gif content #{SecureRandom.hex}"),
          filename: 'animated.gif',
          content_type: 'image/gif'
        )
      end
    end

    trait :with_webp do
      after(:build) do |image|
        image.media.purge if image.media.attached?
        image.media.attach(
          io: StringIO.new("fake webp content #{SecureRandom.hex}"),
          filename: 'modern.webp',
          content_type: 'image/webp'
        )
      end
    end

    trait :without_attribution do
      attribution { nil }
      attribution_url { '' }
    end

    trait :with_long_caption do
      caption { Faker::Lorem.paragraph(sentence_count: 3) }
    end
  end
end
