# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Ai::Log do
  it 'defines the expected table name prefix' do
    expect(described_class.table_name_prefix).to eq('better_together_ai_log_')
  end
end
