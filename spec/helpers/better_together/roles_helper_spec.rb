# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe RolesHelper do
    after { BetterTogether::Resourceful.instance_variable_get(:@registered).delete('Probe::Guild') }

    describe '#role_resource_type_label' do
      it 'names a core resource type from its model name' do
        expect(helper.role_resource_type_label('BetterTogether::Community')).to eq(BetterTogether::Community.model_name.human)
      end

      it 'uses the label a host registered for its own resource type', :aggregate_failures do
        helper.extend(BetterTogether::ResourcePermissionsHelper)
        BetterTogether::Resourceful.register_resource_class('Probe::Guild', label: -> { 'Guilds' })

        expect(helper.role_resource_type_label('Probe::Guild')).to eq('Guilds')
        expect(helper.resource_permission_resource_type_label('Probe::Guild')).to eq('Guilds')
      end

      it 'returns an unknown type unchanged' do
        expect(helper.role_resource_type_label('Probe::Unknown')).to eq('Probe::Unknown')
      end
    end
  end
end
