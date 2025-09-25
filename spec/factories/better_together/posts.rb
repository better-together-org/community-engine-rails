# frozen_string_literal: true

module BetterTogether
  FactoryBot.define do
    sequence(:post_title) { |n| "Sample Post #{n}" }
    sequence(:post_identifier) { |n| "sample-post-#{n}" }

    factory :better_together_post, class: Post, aliases: [:post] do
      id { SecureRandom.uuid }
      title { generate(:post_title) }
      identifier { generate(:post_identifier) }
      content { 'Post content' }

      transient do
        author { create(:better_together_person) }
      end

      after(:build) do |post, evaluator|
        post.authorships.build(author: evaluator.author)
        post.slug = post.identifier
      end
    end
  end
end
