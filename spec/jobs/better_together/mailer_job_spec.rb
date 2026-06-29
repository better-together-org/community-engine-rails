# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MailerJob do
  it 'uses the mailers queue' do
    expect(described_class.queue_name).to eq('mailers')
  end

  it 'inherits from ApplicationJob' do
    expect(described_class.superclass).to eq(BetterTogether::ApplicationJob)
  end
end
