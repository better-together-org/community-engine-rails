# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_content_rich_text, class: 'BetterTogether::Content::RichText' do
    association :creator, factory: :better_together_person
    privacy { 'public' }
    identifier { "rich-text-block-#{SecureRandom.hex(4)}" }

    transient do
      content_html { "<p>#{Faker::Lorem.paragraph}</p>" }
    end

    after(:build) do |block, evaluator|
      block.content = evaluator.content_html if evaluator.content_html.present?
    end

    trait :with_heading do
      content_html { "<h3>#{Faker::Lorem.sentence}</h3><p>#{Faker::Lorem.paragraph}</p>" }
    end

    trait :with_link do
      content_html { "<p>Visit <a href='#{Faker::Internet.url}'>our website</a> for more info.</p>" }
    end

    trait :with_list do
      content_html do
        <<-HTML
          <ul>
            <li>#{Faker::Lorem.sentence}</li>
            <li>#{Faker::Lorem.sentence}</li>
            <li>#{Faker::Lorem.sentence}</li>
          </ul>
        HTML
      end
    end
  end

  # Legacy factory for ActionText::RichText records (kept for backward compatibility)
  factory :content_rich_text, class: 'ActionText::RichText' do
    association :record, factory: :platform
    name { 'body' }
    locale { I18n.default_locale }
    body { '' }
  end

  factory :content_block_rich_text, class: 'BetterTogether::Content::Block::RichText' do # rubocop:todo Lint/EmptyBlock
  end
end
