# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe PeopleHelper do
    describe '#mention_profile_path' do
      let(:person) { create(:better_together_person, privacy: 'private') }
      let(:policy_calls) { [] }

      before do
        calls = policy_calls
        helper.extend(Module.new do
          define_method(:policy) do |record|
            calls << record
            Struct.new(:show?).new(false)
          end

          define_method(:person_path) { |record| "/people/#{record.id}" }
        end)
      end

      it 'returns nil without a person' do
        expect(helper.mention_profile_path(nil)).to be_nil
      end

      it 'links a person found in the prefetched visible set without a policy check', :aggregate_failures do
        helper.instance_variable_set(:@mention_visible_ids, Set[person.id])

        expect(helper.mention_profile_path(person)).to eq("/people/#{person.id}")
        expect(policy_calls).to be_empty
      end

      it 'falls back to the policy check for a person outside the prefetched set', :aggregate_failures do
        helper.instance_variable_set(:@mention_visible_ids, Set.new)

        expect(helper.mention_profile_path(person)).to be_nil
        expect(policy_calls).to eq([person])
      end
    end
  end
end
