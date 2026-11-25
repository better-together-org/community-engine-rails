# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BreakGlassEvent do
  let(:event) { create(:better_together_break_glass_event) }

  it 'cannot be updated' do
    expect { event.update!(event_type: 'revoked') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'cannot be destroyed' do
    expect(event.destroy).to be false
    expect(described_class.exists?(event.id)).to be true
  end

  it 'rejects an unknown event type' do
    expect(build(:better_together_break_glass_event, event_type: 'peeked')).not_to be_valid
  end
end
