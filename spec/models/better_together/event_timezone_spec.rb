# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Event timezone migration' do
  describe 'Event model' do
    it 'has timezone column' do
      expect(BetterTogether::Event.column_names).to include('timezone')
    end

    it 'validates presence of timezone' do
      event = build(:better_together_event, timezone: nil)
      expect(event).not_to be_valid
      expect(event.errors[:timezone]).to include('can\'t be blank')
    end

    it 'validates timezone is a valid IANA timezone' do
      event = build(:better_together_event, timezone: 'InvalidTimezone')
      expect(event).not_to be_valid
      expect(event.errors[:timezone]).to include('InvalidTimezone is not a valid timezone')
    end

    it 'accepts valid IANA timezones' do
      event = build(:better_together_event, timezone: 'America/New_York')
      expect(event).to be_valid
    end

    it 'has default timezone of UTC' do
      event = BetterTogether::Event.new
      expect(event.timezone).to eq('UTC')
    end
  end

  describe 'existing events' do
    it 'can be loaded and saved with timezone' do
      event = create(:better_together_event, timezone: 'Asia/Tokyo')
      reloaded_event = BetterTogether::Event.find(event.id)

      expect(reloaded_event.timezone).to eq('Asia/Tokyo')
    end
  end
end
# rubocop:enable RSpec/DescribeClass
