# frozen_string_literal: true

require 'rails_helper'

# Explicitly load the concern since it may not be autoloaded in test environment
require Rails.root.join('..', '..', 'app', 'models', 'concerns', 'better_together', 'timezone_attribute_aliasing')

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe TimezoneAttributeAliasing do
    # Create a test model with 'timezone' attribute
    let(:timezone_model_class) do
      Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes
        include BetterTogether::TimezoneAttributeAliasing

        attribute :timezone, :string, default: 'UTC'

        def self.model_name
          ActiveModel::Name.new(self, nil, 'TimeZoneModel')
        end
      end
    end

    # Create a test model with 'time_zone' attribute
    let(:time_zone_model_class) do
      Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes
        include BetterTogether::TimezoneAttributeAliasing

        attribute :time_zone, :string, default: 'UTC'

        def self.model_name
          ActiveModel::Name.new(self, nil, 'TimeZoneModel')
        end
      end
    end

    describe 'when model has timezone attribute' do
      subject(:model) { timezone_model_class.new }

      it 'responds to timezone' do
        expect(model).to respond_to(:timezone)
      end

      it 'responds to timezone=' do
        expect(model).to respond_to(:timezone=)
      end

      it 'responds to time_zone (aliased)' do
        expect(model).to respond_to(:time_zone)
      end

      it 'responds to time_zone= (aliased)' do
        expect(model).to respond_to(:time_zone=)
      end

      it 'reads timezone value' do
        model.timezone = 'America/New_York'
        expect(model.timezone).to eq('America/New_York')
      end

      it 'reads time_zone value (via alias)' do
        model.timezone = 'America/New_York'
        expect(model.time_zone).to eq('America/New_York')
      end

      it 'writes timezone value' do
        model.timezone = 'Europe/London'
        expect(model.timezone).to eq('Europe/London')
      end

      it 'writes time_zone value (via alias)' do
        model.time_zone = 'Europe/London'
        expect(model.timezone).to eq('Europe/London')
      end

      it 'maintains consistency between both accessors' do
        model.timezone = 'Asia/Tokyo'
        expect(model.time_zone).to eq('Asia/Tokyo')

        model.time_zone = 'Australia/Sydney'
        expect(model.timezone).to eq('Australia/Sydney')
      end

      it 'returns default value for both accessors' do
        expect(model.timezone).to eq('UTC')
        expect(model.time_zone).to eq('UTC')
      end
    end

    describe 'when model has time_zone attribute' do
      subject(:model) { time_zone_model_class.new }

      it 'responds to time_zone' do
        expect(model).to respond_to(:time_zone)
      end

      it 'responds to time_zone=' do
        expect(model).to respond_to(:time_zone=)
      end

      it 'responds to timezone (aliased)' do
        expect(model).to respond_to(:timezone)
      end

      it 'responds to timezone= (aliased)' do
        expect(model).to respond_to(:timezone=)
      end

      it 'reads time_zone value' do
        model.time_zone = 'America/Chicago'
        expect(model.time_zone).to eq('America/Chicago')
      end

      it 'reads timezone value (via alias)' do
        model.time_zone = 'America/Chicago'
        expect(model.timezone).to eq('America/Chicago')
      end

      it 'writes time_zone value' do
        model.time_zone = 'America/Los_Angeles'
        expect(model.time_zone).to eq('America/Los_Angeles')
      end

      it 'writes timezone value (via alias)' do
        model.timezone = 'America/Los_Angeles'
        expect(model.time_zone).to eq('America/Los_Angeles')
      end

      it 'maintains consistency between both accessors' do
        model.time_zone = 'Pacific/Auckland'
        expect(model.timezone).to eq('Pacific/Auckland')

        model.timezone = 'Europe/Paris'
        expect(model.time_zone).to eq('Europe/Paris')
      end

      it 'returns default value for both accessors' do
        expect(model.time_zone).to eq('UTC')
        expect(model.timezone).to eq('UTC')
      end
    end

    describe 'integration with Event model (has timezone column)', :skip_host_setup do
      let(:event) { create(:better_together_event, timezone: 'America/New_York') }

      it 'responds to both timezone and time_zone' do
        expect(event).to respond_to(:timezone)
        expect(event).to respond_to(:time_zone)
        expect(event).to respond_to(:timezone=)
        expect(event).to respond_to(:time_zone=)
      end

      it 'reads timezone via both accessors' do
        expect(event.timezone).to eq('America/New_York')
        expect(event.time_zone).to eq('America/New_York')
      end

      it 'writes timezone via both accessors' do
        event.timezone = 'Europe/London'
        expect(event.time_zone).to eq('Europe/London')

        event.time_zone = 'Asia/Tokyo'
        expect(event.timezone).to eq('Asia/Tokyo')
      end

      it 'persists changes made via time_zone accessor' do
        event.time_zone = 'Australia/Sydney'
        event.save!
        event.reload
        expect(event.timezone).to eq('Australia/Sydney')
        expect(event.time_zone).to eq('Australia/Sydney')
      end
    end

    describe 'integration with Platform model (has time_zone column)', :skip_host_setup do
      let(:platform) { create(:better_together_platform) }

      before do
        # Ensure Platform has the concern included
        unless BetterTogether::Platform.included_modules.include?(described_class)
          BetterTogether::Platform.include(described_class)
        end
      end

      it 'responds to both time_zone and timezone' do
        expect(platform).to respond_to(:time_zone)
        expect(platform).to respond_to(:timezone)
        expect(platform).to respond_to(:time_zone=)
        expect(platform).to respond_to(:timezone=)
      end

      it 'reads time_zone via both accessors' do
        platform.update!(time_zone: 'America/Chicago')
        expect(platform.time_zone).to eq('America/Chicago')
        expect(platform.timezone).to eq('America/Chicago')
      end

      it 'writes time_zone via both accessors' do
        platform.timezone = 'Europe/Berlin'
        expect(platform.time_zone).to eq('Europe/Berlin')

        platform.time_zone = 'Pacific/Auckland'
        expect(platform.timezone).to eq('Pacific/Auckland')
      end

      it 'persists changes made via timezone accessor' do
        platform.timezone = 'America/Los_Angeles'
        platform.save!
        platform.reload
        expect(platform.time_zone).to eq('America/Los_Angeles')
        expect(platform.timezone).to eq('America/Los_Angeles')
      end

      it 'validates via both accessors' do
        platform.timezone = 'Invalid/Timezone'
        expect(platform).not_to be_valid
        expect(platform.errors[:time_zone]).to be_present

        platform.time_zone = 'America/New_York'
        expect(platform).to be_valid
      end
    end

    describe 'integration with Person model (has time_zone in JSON)', :skip_host_setup do
      let(:person) { create(:better_together_person) }

      before do
        # Ensure Person has the concern included
        unless BetterTogether::Person.included_modules.include?(described_class)
          BetterTogether::Person.include(described_class)
        end
      end

      it 'responds to both time_zone and timezone' do
        expect(person).to respond_to(:time_zone)
        expect(person).to respond_to(:timezone)
        expect(person).to respond_to(:time_zone=)
        expect(person).to respond_to(:timezone=)
      end

      it 'reads time_zone via both accessors' do
        person.time_zone = 'America/Denver'
        expect(person.time_zone).to eq('America/Denver')
        expect(person.timezone).to eq('America/Denver')
      end

      it 'writes time_zone via both accessors' do
        person.timezone = 'Europe/Madrid'
        expect(person.time_zone).to eq('Europe/Madrid')

        person.time_zone = 'Asia/Singapore'
        expect(person.timezone).to eq('Asia/Singapore')
      end

      it 'persists changes made via timezone accessor' do
        person.timezone = 'America/Phoenix'
        person.save!
        person.reload
        expect(person.time_zone).to eq('America/Phoenix')
        expect(person.timezone).to eq('America/Phoenix')
      end

      it 'handles JSON storage correctly' do
        person.timezone = 'Pacific/Honolulu'
        person.save!

        # Verify it's stored in the preferences JSON
        person.reload
        expect(person.preferences['time_zone']).to eq('Pacific/Honolulu')
        expect(person.timezone).to eq('Pacific/Honolulu')
      end
    end
  end
end
