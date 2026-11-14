# frozen_string_literal: true

require 'rails_helper'

# config/initializers/pay.rb: the support email is PAY_SUPPORT_EMAIL, else the app's default from address.
RSpec.describe 'Pay support email' do # rubocop:disable RSpec/DescribeClass
  def support_email_with(env) # rubocop:disable Metrics/AbcSize
    stubbed = { 'PAY_SUPPORT_EMAIL' => nil, 'DEFAULT_FROM_EMAIL' => nil }.merge(env)
    allow(ENV).to receive(:[]).and_call_original
    stubbed.each { |key, value| allow(ENV).to receive(:[]).with(key).and_return(value) }
    original = Pay.support_email
    load BetterTogether::Engine.root.join('config/initializers/pay.rb').to_s
    Pay.support_email.try(:address)
  ensure
    Pay.support_email = original
  end

  it 'is its own address when one is set' do
    expect(support_email_with('PAY_SUPPORT_EMAIL' => 'help@example.org',
                              'DEFAULT_FROM_EMAIL' => 'Hi <hi@example.org>')).to eq('help@example.org')
  end

  it 'is the app\'s from address when none is set' do
    expect(support_email_with('DEFAULT_FROM_EMAIL' => 'Hi <hi@example.org>')).to eq('hi@example.org')
  end

  it 'is blank when neither is set' do
    expect(support_email_with({})).to be_blank
  end
end
