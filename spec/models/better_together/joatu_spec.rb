# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu do
  it 'defines the expected table name prefix' do
    expect(described_class.table_name_prefix).to eq('better_together_joatu_')
  end
end
