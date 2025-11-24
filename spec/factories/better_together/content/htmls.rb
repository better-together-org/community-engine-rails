# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_content_html, class: 'BetterTogether::Content::Html' do
    content { "<div>#{Faker::Lorem.paragraph}</div>" }

    trait :with_heading do
      content { "<h2>#{Faker::Lorem.sentence}</h2><p>#{Faker::Lorem.paragraph}</p>" }
    end

    trait :with_link do
      content { "<a href='#{Faker::Internet.url}'>#{Faker::Lorem.words(number: 2).join(' ')}</a>" }
    end

    trait :with_list do
      content do
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

  factory :content_html, parent: :better_together_content_html
end
