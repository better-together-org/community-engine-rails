# frozen_string_literal: true

FactoryBot.define do
  factory :content_template, class: 'BetterTogether::Content::Template' do
    template_path { 'better_together/content/blocks/template/default' }
  end
end
