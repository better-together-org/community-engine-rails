# frozen_string_literal: true

# FactoryBot factories for BetterTogether models.
module BetterTogether # :nodoc:
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

      before(:create) do |post|
        unless post.platform_id.present?
          post.platform = Current.platform ||
                          BetterTogether::Platform.find_by(host: true) ||
                          create(:better_together_platform)
        end
      end

      trait :public do
        privacy { 'public' }
      end

      trait :community do
        privacy { 'community' }
      end

      trait :published do
        published_at { 1.day.ago }
      end

      trait :with_categories do
        transient do
          categories_count { 2 }
        end

        after(:build) do |post, evaluator|
          post.categories = create_list(:better_together_category, evaluator.categories_count)
        end
      end
    end
  end
end
