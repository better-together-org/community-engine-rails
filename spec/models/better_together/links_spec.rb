# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Links do
  it 'defines the expected table name prefix' do
    expect(described_class.table_name_prefix).to eq('better_together_links_')
  end
end
