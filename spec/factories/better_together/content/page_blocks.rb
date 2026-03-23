# frozen_string_literal: true

FactoryBot.define do
  factory :page_content_block, class: 'BetterTogether::Content::PageBlock',
                               aliases: %i[better_together_page_block better_together_content_page_block] do
    association :page, factory: :page
    association :block, factory: :content_markdown
  end
end
