# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Federation::Transport::Resolution, type: :service do
  it 'holds tier and adapter_class after construction' do
    resolution = described_class.new(:direct, BetterTogether::Federation::Transport::DirectAdapter)
    expect(resolution.tier).to eq(:direct)
    expect(resolution.adapter_class).to eq(BetterTogether::Federation::Transport::DirectAdapter)
  end

  it 'has exactly tier and adapter_class as members' do
    expect(described_class.members).to eq(%i[tier adapter_class])
  end

  it 'constructs with nil values when no arguments are given' do
    resolution = described_class.new
    expect(resolution.tier).to be_nil
    expect(resolution.adapter_class).to be_nil
  end

  it 'compares equal when tier and adapter_class match' do
    a = described_class.new(:http, BetterTogether::Federation::Transport::HttpAdapter)
    b = described_class.new(:http, BetterTogether::Federation::Transport::HttpAdapter)
    expect(a).to eq(b)
  end
end
