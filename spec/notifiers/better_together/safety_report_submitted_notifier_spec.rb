# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SafetyReportSubmittedNotifier do
  subject(:notifier) do
    described_class.new(
      record: report,
      params: { report: report }
    )
  end

  let(:report) { create(:report, harm_level: 'medium') }
  let(:reviewer) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: reviewer) }

  describe '#title' do
    it 'describes a safety report review' do
      expect(notifier.title).to be_present
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end

    context 'when harm level is urgent' do
      let(:report) { create(:report, harm_level: 'urgent') }

      it 'reflects urgency in the title' do
        expect(notifier.title).to match(/urgent/i)
      end
    end
  end

  describe '#body' do
    it 'includes the harm level' do
      expect(notifier.body).to include('medium')
    end

    it 'includes the reportable type' do
      expect(notifier.body).to include('Person')
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
