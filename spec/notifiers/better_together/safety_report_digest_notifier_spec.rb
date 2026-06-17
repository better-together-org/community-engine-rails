# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SafetyReportDigestNotifier do
  subject(:notifier) do
    described_class.new(
      record: platform,
      params: {
        platform: platform,
        report_ids: [report.id],
        report_count: 5,
        urgent_count: 2,
        retaliation_risk_count: 1,
        review_url: 'https://example.com/safety_cases'
      }
    )
  end

  let(:platform) { create(:better_together_platform) }
  let(:report) { create(:report) }
  let(:reviewer) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: reviewer) }

  describe '#title' do
    it 'includes the report count' do
      expect(notifier.title).to include('5')
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end
  end

  describe '#body' do
    it 'includes the urgent count' do
      expect(notifier.body).to include('2')
    end

    it 'includes the retaliation risk count' do
      expect(notifier.body).to include('1')
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.body }.not_to raise_error
    end
  end

  describe '#locale' do
    it 'returns a locale without calling recipient' do
      expect { notifier.locale }.not_to raise_error
      expect(notifier.locale).to eq(I18n.default_locale)
    end
  end

  describe '#build_message' do
    it 'returns a hash with title, body, and url' do
      message = notifier.build_message(notification)

      expect(message).to include(:title, :body, :url)
    end

    it 'does not raise NameError from bare recipient reference' do
      expect { notifier.build_message(notification) }.not_to raise_error
    end

    it 'includes a URL to the safety cases queue' do
      message = notifier.build_message(notification)

      expect(message[:url]).to include('safety_cases')
    end
  end
end
