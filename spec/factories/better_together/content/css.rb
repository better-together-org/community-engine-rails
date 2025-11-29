# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_content_css, class: 'BetterTogether::Content::Css' do
    association :creator, factory: :better_together_person
    privacy { 'public' }
    identifier { "css-block-#{SecureRandom.hex(4)}" }

    transient do
      content_text { '.my-class { color: red; }' }
    end

    after(:build) do |css_block, evaluator|
      css_block.content = evaluator.content_text if evaluator.content_text.present?
    end

    after(:create) do |css_block, evaluator|
      if evaluator.content_text.present?
        css_block.update(content: evaluator.content_text)
      end
    end

    trait :with_complex_css do
      transient do
        content_text do
          <<~CSS
            .leaflet-top, .leaflet-bottom { z-index: 999; }
            .notification form[action*="mark_as_read"] .btn[type="submit"] { z-index: 1200; }
            .card.journey-stage > .card-body { max-height: 50vh; }
            @media only screen and (min-width: 768px) {
              .hero-heading { font-size: 3em; }
            }
          CSS
        end
      end
    end

    trait :with_dangerous_css do
      transient do
        content_text { 'width: expression(alert("XSS")); background: url(javascript:void(0));' }
      end
    end

    trait :empty do
      transient do
        content_text { nil }
      end
    end
  end
end
