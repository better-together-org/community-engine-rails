# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationHelper, type: :helper do
  describe 'timezone helpers' do
    describe '#iana_timezone_options_for_select' do
      let(:options) { helper.iana_timezone_options_for_select }

      context 'display format (AC-1.1)' do
        it 'shows only Rails-friendly names without IANA suffix' do
          # Find option for America/New_York
          new_york_option = options.find { |opt| opt[1] == 'America/New_York' }
          expect(new_york_option).to be_present
          expect(new_york_option[0]).to eq('(GMT-05:00) Eastern Time (US & Canada)')
          expect(new_york_option[0]).not_to include('America/New_York')
        end

        it 'handles timezones without Rails name mapping' do
          # Some timezones may not have Rails friendly names
          option = options.find { |opt| opt[1] == 'UTC' }
          expect(option).to be_present
          expect(option[0]).to be_present
        end
      end

      context 'UTC offset sorting (AC-1.2)' do
        it 'sorts timezones by UTC offset ascending' do
          offsets = options.map do |opt|
            ActiveSupport::TimeZone[opt[1]]&.utc_offset || 0
          end
          expect(offsets).to eq(offsets.sort)
        end

        it 'starts with most negative offsets (GMT-12)' do
          first_offset = ActiveSupport::TimeZone[options.first[1]]&.utc_offset
          expect(first_offset).to be <= -39_600 # GMT-11 or earlier
        end

        it 'ends with most positive offsets (GMT+13/+14)' do
          last_offset = ActiveSupport::TimeZone[options.last[1]]&.utc_offset
          expect(last_offset).to be >= 43_200 # GMT+12 or later
        end
      end

      context 'secondary alphabetical sorting (AC-1.3)' do
        it 'sorts alphabetically within same UTC offset' do
          # Group by UTC offset
          grouped = options.group_by do |opt|
            ActiveSupport::TimeZone[opt[1]]&.utc_offset
          end

          # Check each group is alphabetically sorted
          grouped.each do |_offset, zones|
            names = zones.map { |opt| opt[0] }
            expect(names).to eq(names.sort), 'Zones with same offset should be alphabetically sorted'
          end
        end

        it 'sorts America/Detroit and America/New_York alphabetically (both GMT-5)' do
          est_zones = options.select do |opt|
            tz = ActiveSupport::TimeZone[opt[1]]
            tz&.utc_offset == -18_000 # GMT-5
          end

          detroit = est_zones.find { |opt| opt[1] == 'America/Detroit' }
          new_york = est_zones.find { |opt| opt[1] == 'America/New_York' }

          next unless detroit && new_york

          detroit_index = est_zones.index(detroit)
          new_york_index = est_zones.index(new_york)

          # When using Rails-friendly display names:
          # New York: "(GMT-05:00) Eastern Time (US & Canada)" comes before
          # Detroit: "America/Detroit" (no Rails mapping, uses IANA ID)
          # Because "(" < "A" alphabetically
          expect(new_york_index).to be < detroit_index
        end
      end

      context 'value storage (AC-1.4)' do
        it 'stores IANA identifier as option value' do
          new_york_option = options.find { |opt| opt[1] == 'America/New_York' }
          expect(new_york_option[1]).to eq('America/New_York')
        end

        it 'all options have IANA identifier values' do
          options.each do |opt|
            expect(TZInfo::Timezone.all_identifiers).to include(opt[1])
          end
        end
      end
    end

    describe '#priority_timezone_options' do
      let(:priority_options) { helper.priority_timezone_options }

      context 'priority zone count (AC-2.2)' do
        it 'returns exactly 25 priority timezones' do
          expect(priority_options.length).to eq(25)
        end

        it 'includes expected priority zones' do
          priority_ids = priority_options.map { |opt| opt[1] }
          expect(priority_ids).to include(
            'UTC',
            'America/New_York',
            'America/Chicago',
            'America/Denver',
            'America/Los_Angeles',
            'America/Toronto',
            'America/Vancouver',
            'Europe/London',
            'Europe/Paris',
            'Asia/Tokyo',
            'Pacific/Auckland',
            'Australia/Sydney'
          )
        end

        it 'includes all continents in priority list' do
          priority_ids = priority_options.map { |opt| opt[1] }
          continents = priority_ids.map { |tz| tz.split('/').first }.uniq
          expect(continents).to include('America', 'Europe', 'Asia', 'Pacific', 'Australia', 'Africa')
        end
      end

      context 'priority zone sorting (AC-2.3)' do
        it 'sorts priority zones by UTC offset' do
          offsets = priority_options.map do |opt|
            ActiveSupport::TimeZone[opt[1]]&.utc_offset || 0
          end
          expect(offsets).to eq(offsets.sort)
        end

        it 'sorts alphabetically within same offset for priority zones' do
          grouped = priority_options.group_by do |opt|
            ActiveSupport::TimeZone[opt[1]]&.utc_offset
          end

          grouped.each do |_offset, zones|
            names = zones.map { |opt| opt[0] }
            expect(names).to eq(names.sort)
          end
        end
      end
    end

    describe '#iana_timezone_options_grouped' do
      let(:grouped_options) { helper.iana_timezone_options_grouped }

      context 'continent grouping (AC-3.1)' do
        it 'groups timezones by continent' do
          expect(grouped_options.keys).to include(
            'Africa', 'America', 'Asia', 'Europe', 'Pacific'
          )
        end

        it 'includes UTC group' do
          expect(grouped_options.keys).to include('UTC')
        end

        it 'has all major continents represented' do
          expect(grouped_options.keys.length).to be >= 6
        end
      end

      context 'deduplication from priority zones (AC-2.4, AC-3.3)' do
        it 'excludes zones already in COMMON_TIMEZONES from continent groups' do
          # Get priority zone IDs
          priority_ids = BetterTogether::ApplicationHelper::COMMON_TIMEZONES

          # Check each continent group
          grouped_options.each do |_continent, zones|
            zone_ids = zones.map { |opt| opt[1] }
            priority_ids.each do |priority_id|
              expect(zone_ids).not_to include(priority_id),
                                      "#{priority_id} should not appear in continent groups"
            end
          end
        end

        it 'excludes America/New_York from America group' do
          america_zones = grouped_options['America']
          next unless america_zones

          america_ids = america_zones.map { |opt| opt[1] }
          expect(america_ids).not_to include('America/New_York')
        end

        it 'excludes Europe/London from Europe group' do
          europe_zones = grouped_options['Europe']
          next unless europe_zones

          europe_ids = europe_zones.map { |opt| opt[1] }
          expect(europe_ids).not_to include('Europe/London')
        end
      end

      context 'continent group sorting (AC-3.2)' do
        it 'sorts each continent group by UTC offset then name' do
          grouped_options.each do |continent, zones|
            offsets = zones.map { |opt| ActiveSupport::TimeZone[opt[1]]&.utc_offset || 0 }
            expect(offsets).to eq(offsets.sort), "#{continent} group should be sorted by offset"

            # Within same offset, check alphabetical
            grouped_by_offset = zones.group_by do |opt|
              ActiveSupport::TimeZone[opt[1]]&.utc_offset
            end
            grouped_by_offset.each do |_offset, offset_zones|
              names = offset_zones.map { |opt| opt[0] }
              expect(names).to eq(names.sort)
            end
          end
        end
      end
    end

    describe '#iana_timezone_options_with_priority' do
      let(:options_with_priority) { helper.iana_timezone_options_with_priority }

      context 'priority optgroup first (AC-2.1)' do
        it 'has "Common Timezones" as first optgroup' do
          expect(options_with_priority).to be_a(Array)
          expect(options_with_priority.first).to be_a(Array)
          expect(options_with_priority.first[0]).to eq('Common Timezones')
        end

        it 'contains 25 priority zones in first optgroup' do
          expect(options_with_priority.first[1].length).to eq(25)
        end

        it 'first optgroup zones are properly formatted' do
          priority_group = options_with_priority.first[1]
          priority_group.each do |opt|
            expect(opt).to be_a(Array)
            expect(opt.length).to eq(2)
            expect(opt[0]).to be_a(String) # Display name
            expect(opt[1]).to be_a(String) # IANA identifier
          end
        end
      end

      context 'continent optgroups follow (AC-3.1)' do
        it 'has continent groups after priority group' do
          continent_labels = options_with_priority[1..].map { |group| group[0] }
          expect(continent_labels).to include('America', 'Europe', 'Asia', 'Pacific')
        end

        it 'all groups after first are continent groups' do
          options_with_priority[1..].each do |group|
            expect(group).to be_a(Array)
            expect(group.length).to eq(2)
            expect(group[0]).to be_a(String) # Continent name
            expect(group[1]).to be_a(Array) # Array of timezone options
          end
        end
      end

      context 'no duplication between groups (AC-2.4)' do
        it 'each timezone appears in only one group' do
          all_zone_ids = []
          options_with_priority.each do |group|
            zones = group[1]
            zone_ids = zones.map { |opt| opt[1] }
            duplicates = zone_ids & all_zone_ids
            expect(duplicates).to be_empty, "Duplicate timezones found: #{duplicates.join(', ')}"
            all_zone_ids.concat(zone_ids)
          end
        end
      end
    end

    describe '#iana_time_zone_select' do
      let(:event) { build(:better_together_event) }
      let(:form_builder) { ActionView::Helpers::FormBuilder.new(:event, event, helper, {}) }

      context 'SlimSelect integration (AC-4.1)' do
        it 'includes SlimSelect controller data attribute' do
          result = helper.iana_time_zone_select(
            form_builder,
            :timezone,
            nil,
            {},
            { data: { controller: 'better_together--slim-select' } }
          )
          expect(result).to include('data-controller="better_together--slim-select"')
        end
      end

      context 'SlimSelect configuration (AC-5.1)' do
        it 'includes SlimSelect options data attribute with correct settings' do
          slim_select_options = {
            settings: {
              allowDeselect: false,
              searchPlaceholder: 'Search timezones...',
              closeOnSelect: true,
              showSearch: true
            }
          }

          result = helper.iana_time_zone_select(
            form_builder,
            :timezone,
            nil,
            {},
            {
              data: {
                controller: 'better_together--slim-select',
                'better_together--slim-select-options-value': slim_select_options.to_json
              }
            }
          )

          expect(result).to include('data-better-together--slim-select-options-value')
          expect(result).to include('allowDeselect')
          expect(result).to include('searchPlaceholder')
        end
      end

      context 'grouped options structure (AC-3.4)' do
        it 'uses grouped_options_for_select with priority and continent groups' do
          result = helper.iana_time_zone_select(form_builder, :timezone)
          expect(result).to include('<optgroup label="Common Timezones">')
          expect(result).to(include('<optgroup label="America">').or(include('<optgroup label="Europe">')))
        end
      end

      context 'backward compatibility' do
        it 'works with selected option parameter' do
          result = helper.iana_time_zone_select(
            form_builder,
            :timezone,
            'America/New_York'
          )
          expect(result).to include('selected')
          expect(result).to include('America/New_York')
        end

        it 'works with options hash selected' do
          result = helper.iana_time_zone_select(
            form_builder,
            :timezone,
            nil,
            { selected: 'Europe/London' }
          )
          expect(result).to include('Europe/London')
        end
      end
    end
  end
end
