# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformContextJobCarrier do
  let(:job_class) do
    Class.new(ActiveJob::Base) do
      cattr_accessor :seen_platform_id

      def self.name = 'PlatformContextProbeJob'

      def perform
        self.class.seen_platform_id = Current.platform&.id
      end
    end
  end
  let(:hosted) { create(:better_together_platform, host: false, privacy: 'public') }

  before do
    configure_host_platform
    stub_const('PlatformContextProbeJob', job_class)
    job_class.seen_platform_id = nil
  end

  after { Current.reset }

  it 'restores the platform that queued the job when it runs' do
    Current.platform = hosted
    payload = job_class.new.serialize
    Current.reset

    ActiveJob::Base.execute(payload)

    expect(job_class.seen_platform_id).to eq(hosted.id)
  end

  it 'does not leave the platform set after the job runs' do
    Current.platform = hosted
    payload = job_class.new.serialize
    Current.reset

    ActiveJob::Base.execute(payload)

    expect(Current.platform).to be_nil
  end

  it 'runs a job queued with no platform without one' do
    payload = job_class.new.serialize

    ActiveJob::Base.execute(payload)

    expect(job_class.seen_platform_id).to be_nil
  end

  it 'keeps the platform across a retry re-serialization' do
    Current.platform = hosted
    job = job_class.deserialize(job_class.new.serialize)
    Current.reset

    expect(job.serialize[described_class::SERIALIZED_KEY]).to eq(hosted.id)
  end

  it 'runs without a platform when the carried platform no longer exists' do
    Current.platform = hosted
    payload = job_class.new.serialize
    Current.reset
    payload[described_class::SERIALIZED_KEY] = SecureRandom.uuid

    ActiveJob::Base.execute(payload)

    expect(job_class.seen_platform_id).to be_nil
  end

  describe 'mail queued with deliver_later' do
    let(:mailer) do
      Class.new(BetterTogether::ApplicationMailer) do
        def probe
          mail(to: 'a@example.test', subject: 'probe') do |format| # rubocop:disable Rails/I18nLocaleTexts
            format.text { render plain: default_url_options[:host].to_s }
          end
        end
      end
    end

    before { stub_const('CarrierProbeMailer', mailer) }

    it 'renders links on the primary domain of the platform that queued the mail' do
      hosted.platform_domains.update_all(primary: false)
      create(:better_together_platform_domain, platform: hosted, hostname: 'club.carrier.test',
                                               primary: true, active: true)
      hosted.reload
      Current.platform = hosted
      payload = ActionMailer::MailDeliveryJob.new('CarrierProbeMailer', 'probe', 'deliver_now', args: []).serialize
      Current.reset
      ActionMailer::Base.deliveries.clear

      ActiveJob::Base.execute(payload)

      expect(ActionMailer::Base.deliveries.last.body.to_s).to include('club.carrier.test')
    end
  end
end
