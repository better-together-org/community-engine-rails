# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlakeForensics do
  let(:example_double) do
    instance_double(RSpec::Core::Example,
                    exception: StandardError.new('Validation failed: Agreement has already been taken'),
                    metadata: { location: './spec/x_spec.rb:1', type: :request })
  end

  it 'prints a report for a state-leak failure, including committed row counts', :aggregate_failures do
    expect { described_class.report(example_double) }
      .to output(/FLAKE-FORENSICS.*\n.*pid=.*\n.*committed rows.*agreement_participants=\d+/).to_stderr
  end

  it 'stays silent for unrelated failures' do
    other = instance_double(RSpec::Core::Example, exception: RuntimeError.new('boom'), metadata: { location: 'x' })

    expect { described_class.report(other) }.not_to output.to_stderr
  end

  it 'keeps only the most recent examples' do
    (described_class::RECENT_LIMIT + 3).times { |i| described_class.remember(instance_double(RSpec::Core::Example, metadata: { location: "l#{i}" })) }

    expect(described_class::RECENT.size).to eq(described_class::RECENT_LIMIT)
  end
end
