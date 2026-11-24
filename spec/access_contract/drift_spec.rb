# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Access contract drift' do # rubocop:disable RSpec/DescribeClass
  let(:contract) { BetterTogether::AccessContract::Contract.load }
  let(:drift) { BetterTogether::AccessContract::Drift.new(contract) }
  let(:invariants) { BetterTogether::AccessContract::Invariants.new(contract) }

  it 'has a valid contract' do
    expect(contract.problems).to be_empty, contract.problems.join("\n")
  end

  it 'matches the probe snapshot cell for cell' do
    expect(drift.diffs.map(&:to_s)).to be_empty, "Contract and snapshot differ:\n#{drift.diffs.join("\n")}"
  end

  it 'lists known deviations and undecided cells with decisions' do
    ids = (drift.known_deviations + drift.undecided).map { |c| (c.deviation || c.undecided)['decision'] }.uniq
    expect(ids - contract.decisions.keys).to be_empty
  end

  describe 'invariants' do
    it 'holds every invariant' do
      failures = invariants.all.reject { |_, v| v.empty? }.map { |name, v| "#{name}:\n  #{v.join("\n  ")}" }
      expect(failures).to be_empty, failures.join("\n")
    end
  end

  it 'keeps generated docs current' do
    stale = BetterTogether::AccessContract::DocsGenerator.new.stale
    expect(stale).to be_empty, "Run rake better_together:access:docs. Stale: #{stale.join(', ')}"
  end
end
