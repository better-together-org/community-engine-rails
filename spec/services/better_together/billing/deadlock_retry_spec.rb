# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::DeadlockRetry do
  it 'runs the block again after a deadlock and returns its value' do
    calls = 0
    result = described_class.run do
      calls += 1
      raise ActiveRecord::Deadlocked if calls < 3

      :done
    end

    expect([calls, result]).to eq([3, :done])
  end

  it 'gives up after the last attempt' do
    calls = 0

    expect { described_class.run { calls += 1 and raise ActiveRecord::Deadlocked } }.to raise_error(ActiveRecord::Deadlocked)
    expect(calls).to eq(described_class::ATTEMPTS)
  end
end
