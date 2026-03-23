# frozen_string_literal: true

FactoryBot.define do
  factory :user_account_report, class: 'BetterTogether::Metrics::UserAccountReport' do
    association :creator, factory: :person
    file_format { 'csv' }
    filters do
      {
        from_date: 30.days.ago.to_date.to_s,
        to_date: Date.current.to_s
      }
    end
    report_data do
      {
        'summary' => {},
        'daily_stats' => [],
        'registration_sources' => {}
      }
    end

    trait :with_data do
      report_data do
        {
          'summary' => {
            'total_accounts_created' => 10,
            'total_accounts_confirmed' => 8,
            'confirmation_rate' => 80.0
          },
          'daily_stats' => [
            { 'date' => '2024-01-01', 'accounts_created' => 5, 'accounts_confirmed' => 4 },
            { 'date' => '2024-01-02', 'accounts_created' => 5, 'accounts_confirmed' => 4 }
          ],
          'registration_sources' => {
            'open_registration' => 6,
            'invitation' => 3,
            'oauth' => 1
          }
        }
      end
    end

    trait :with_file do
      after(:create) do |report|
        report.report_file.attach(
          io: StringIO.new('Date,Accounts Created,Accounts Confirmed\n2024-01-01,5,4'),
          filename: 'user_account_report.csv',
          content_type: 'text/csv'
        )
      end
    end
  end
end
