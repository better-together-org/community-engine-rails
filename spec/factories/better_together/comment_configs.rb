# frozen_string_literal: true

FactoryBot.define do
  factory :comment_config, class: 'BetterTogether::CommentConfig' do
    association :commentable, factory: :better_together_post
    permission { 'inherit' }
    visibility { 'inherit' }
  end
end
