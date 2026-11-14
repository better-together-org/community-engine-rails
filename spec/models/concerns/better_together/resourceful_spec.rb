# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Resourceful do
  let(:registered) { described_class.instance_variable_get(:@registered) }

  after { registered.delete('Probe::Thing') }

  it 'allows only the core resource classes until a host registers more', :aggregate_failures do
    expect(described_class.allowed_resource_classes).to eq(described_class::RESOURCE_CLASSES)
    expect(build(:better_together_role, resource_type: 'Probe::Thing')).not_to be_valid
  end

  it 'accepts a registered resource type on roles and permissions', :aggregate_failures do
    described_class.register_resource_class('Probe::Thing')

    expect(build(:better_together_role, resource_type: 'Probe::Thing')).to be_valid
    expect(build(:better_together_resource_permission, resource_type: 'Probe::Thing')).to be_valid
  end

  it 'resolves a registered label from a string or a callable', :aggregate_failures do
    described_class.register_resource_class('Probe::Thing', label: -> { 'Probe things' })

    expect(described_class.label_for('Probe::Thing')).to eq('Probe things')
    expect(described_class.label_for('BetterTogether::Community')).to be_nil
  end
end
