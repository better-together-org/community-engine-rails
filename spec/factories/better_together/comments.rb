# frozen_string_literal: true

FactoryBot.define do
  sequence(:comment_content) { |n| "Sample comment #{n}" }

  factory :comment, class: 'BetterTogether::Comment' do
    content { generate(:comment_content) }
    creator { create(:better_together_person) }

    transient do
      commentable { create(:better_together_post) }
    end

    after(:build) do |comment, evaluator|
      comment.commentable = evaluator.commentable
    end
  end
end
