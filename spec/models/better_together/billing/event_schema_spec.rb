# frozen_string_literal: true

require 'rails_helper'

# Locks in the schema fix from ReconcileBetterTogetherBillingEventsBeneficiaryColumns:
# beneficiary_type/beneficiary_id are live columns the Event model requires; community_id
# was dead/orphaned schema.rb drift with no application code reading/writing it. This spec
# exists so a future schema.rb regen can't silently reintroduce either problem.
RSpec.describe BetterTogether::Billing::Event do
  subject(:event) { build(:better_together_billing_event) }

  describe 'database' do
    it { is_expected.to have_db_column(:beneficiary_type).of_type(:string) }
    it { is_expected.to have_db_column(:beneficiary_id).of_type(:uuid) }

    it 'does not have a dead community_id column' do
      expect(described_class.column_names).not_to include('community_id')
    end

    it 'indexes beneficiary_type/beneficiary_id together' do
      index = ActiveRecord::Base.connection.indexes(described_class.table_name)
                                .find { |idx| idx.name == 'idx_bt_billing_events_beneficiary' }

      expect(index&.columns).to contain_exactly('beneficiary_type', 'beneficiary_id')
    end
  end
end
