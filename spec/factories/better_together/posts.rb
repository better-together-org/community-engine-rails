# frozen_string_literal: true

module BetterTogether
  FactoryBot.define do
    factory :better_together_post, class: Post, aliases: [:post] do
      id { SecureRandom.uuid }
      title { 'Sample Post' }
      content { 'Post content' }

      transient do
        author { create(:better_together_person) }
      end

      after(:build) do |post, evaluator|
        post.authorships.build(author: evaluator.author)
      end
    end
  end
end
