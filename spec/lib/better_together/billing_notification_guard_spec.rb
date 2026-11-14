# frozen_string_literal: true

require 'rails_helper'

# Billing tells people through Noticed, in their language, on the billing queue. Pay's own mailers
# would send the same messages unbranded, untranslated and to whatever email Pay has on file, so they
# stay off, and nothing here may call them.
RSpec.describe 'Billing notification guard' do # rubocop:disable RSpec/DescribeClass
  let(:root) { BetterTogether::Engine.root }
  let(:billing_files) do
    %w[app/models app/services app/controllers app/jobs app/notifiers app/mailers app/policies].flat_map do |dir|
      Dir[root.join(dir, '**/*.rb')].select { |file| file.include?('billing') }
    end
  end

  it 'keeps Pay\'s own emails off' do
    expect(Pay.send_emails).to be(false)
    %i[receipt refund payment_failed payment_action_required subscription_renewing subscription_trial_will_end subscription_trial_ended]
      .each { |name| expect(Pay.send_email?(name, nil)).to be(false), "Pay would send #{name}" }
  end

  it 'never calls Pay\'s mailer from billing code' do
    offenders = billing_files.select { |file| File.read(file).match?(/Pay\.mailer|Pay::UserMailer|pay_user_mailer/) }

    expect(offenders.map { |file| file.delete_prefix("#{root}/") }).to eq([])
  end

  it 'has a notification for each message Pay would have sent' do
    pay_messages = %w[payment_succeeded refund_issued subscription_renewing payment_action_required payment_failed trial_ending trial_ended]

    expect(BetterTogether::Billing::Notifications::Catalog::KINDS.keys).to include(*pay_messages)
  end

  it 'sends billing deliveries on the billing queue, not the general ones' do
    source = root.join('app/notifiers/better_together/billing/notifier.rb').read

    expect(source.scan(/queue: :(\w+)/).flatten.uniq).to eq(['billing'])
  end

  it 'has its notifier stamped from its record, never the ambient platform' do
    source = root.join('app/notifiers/better_together/billing/notifier.rb').read

    expect(source).to include('record.platform_id')
  end
end
