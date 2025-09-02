# frozen_string_literal: true

FactoryBot.define do
  factory :content_rich_text, class: 'ActionText::RichText' do
    association :record, factory: :platform
  name { 'body' }
    locale { I18n.default_locale }
    body { '' }
  end

  factory :content_block_rich_text, class: 'BetterTogether::Content::Block::RichText' do # rubocop:todo Lint/EmptyBlock
  end
end
