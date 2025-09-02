# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_rich_text_link, class: 'Metrics::RichTextLink' do
    # minimal factory to satisfy linter; expand in tests as needed
    initialize_with { new }
  end
end
