# frozen_string_literal: true

require 'rails_helper'
require 'better_together/access_contract'
require_relative '../support/access_contract/probe'

# Builds fixtures for every persona and record state, calls every policy action and
# Scope#resolve of the pilot resources, and compares the result with the committed snapshot.
# Regenerate the snapshot after an intentional policy change:
#   bin/dc-run env ACCESS_SNAPSHOT=write bundle exec prspec spec/access_contract/probe_spec.rb
RSpec.describe 'Access contract probe' do # rubocop:disable RSpec/DescribeClass
  include_context 'with billing switched on'
  include_context 'with clean billing processors'

  let(:contract) { BetterTogether::AccessContract::Contract.load }
  let(:snapshot_path) { BetterTogether::AccessContract.root.join(BetterTogether::AccessContract::SNAPSHOT_PATH) }

  before { configure_host_platform }

  it 'records the actual behaviour of every pilot policy without errors' do
    actual = AccessContractProbe::Runner.new(contract).run
    errors = BetterTogether::AccessContract::Snapshot.flatten(actual).select { |_, v| v.start_with?('error') }
    expect(errors).to eq({})

    rendered = BetterTogether::AccessContract::Snapshot.dump(actual)
    if ENV['ACCESS_SNAPSHOT'] == 'write'
      File.write(snapshot_path, rendered)
    else
      expect(rendered).to eq(File.read(snapshot_path)), 'Snapshot is stale. Run with ACCESS_SNAPSHOT=write and review the diff.'
    end
  end
end
