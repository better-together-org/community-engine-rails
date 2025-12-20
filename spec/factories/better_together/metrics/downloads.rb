# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_download, class: 'BetterTogether::Metrics::Download' do
    file_name { Faker::File.file_name(ext: %w[pdf doc xls].sample) }
    file_type { %w[pdf doc xls].sample }
    file_size { Faker::Number.between(from: 1024, to: 10_485_760) }
    locale { I18n.available_locales.sample.to_s }
    downloaded_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }
  end
end
