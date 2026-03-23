# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_content_hero, class: 'BetterTogether::Content::Hero' do
    transient do
      title { Faker::Lorem.sentence }
      subtitle { Faker::Lorem.paragraph }
    end

    heading { title }
    content { subtitle }
    cta_text { Faker::Lorem.words(number: 2).join(' ') }
    cta_url { Faker::Internet.url }
    cta_button_style { 'btn-primary' }
    css_classes { 'text-white' }
    container_class { '' }
    overlay_color { '#000' }
    overlay_opacity { 0.25 }

    trait :with_background_image do
      after(:create) do |hero|
        hero.background_image_file.attach(
          io: StringIO.new('fake image content'),
          filename: 'hero_background.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    trait :primary_button do
      cta_button_style { 'btn-primary' }
    end

    trait :secondary_button do
      cta_button_style { 'btn-secondary' }
    end

    trait :dark_overlay do
      overlay_color { '#000' }
      overlay_opacity { 0.5 }
    end

    trait :light_overlay do
      overlay_color { '#fff' }
      overlay_opacity { 0.3 }
    end
  end

  factory :content_hero, parent: :better_together_content_hero
end
