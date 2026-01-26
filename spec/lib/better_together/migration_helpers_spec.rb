# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength, RSpec/StubbedMock, RSpec/VerifiedDoubles, RSpec/RepeatedExample
module BetterTogether
  RSpec.describe MigrationHelpers do
    # Create a test migration class to include the module
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[7.1]) do
        include BetterTogether::MigrationHelpers
      end
    end

    let(:migration) { migration_class.new }

    describe '#create_bt_table' do
      context 'with default prefix' do
        it 'creates table with better_together prefix' do
          expect(migration).to receive(:create_table)
            .with('better_together_test_models', id: :uuid)
            .and_yield(double('TableDefinition',
                              integer: nil,
                              timestamps: nil))

          migration.create_bt_table(:test_models) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      context 'with custom prefix' do
        it 'creates table with custom prefix' do
          expect(migration).to receive(:create_table)
            .with('custom_test_models', id: :uuid)
            .and_yield(double('TableDefinition',
                              integer: nil,
                              timestamps: nil))

          migration.create_bt_table(:test_models, prefix: 'custom') { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      context 'with no prefix' do
        it 'creates table without prefix' do
          expect(migration).to receive(:create_table)
            .with('test_models', id: :uuid)
            .and_yield(double('TableDefinition',
                              integer: nil,
                              timestamps: nil))

          migration.create_bt_table(:test_models, prefix: nil) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      context 'with false prefix' do
        it 'creates table without prefix' do
          expect(migration).to receive(:create_table)
            .with('test_models', id: :uuid)
            .and_yield(double('TableDefinition',
                              integer: nil,
                              timestamps: nil))

          migration.create_bt_table(:test_models, prefix: false) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      context 'with custom id type' do
        it 'uses specified id type' do
          expect(migration).to receive(:create_table)
            .with('better_together_test_models', id: :bigint)
            .and_yield(double('TableDefinition',
                              integer: nil,
                              timestamps: nil))

          migration.create_bt_table(:test_models, id: :bigint) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      it 'adds lock_version column' do
        table_definition = double('TableDefinition')
        expect(table_definition).to receive(:integer)
          .with(:lock_version, null: false, default: 0)
        expect(table_definition).to receive(:timestamps).with(null: false)

        expect(migration).to receive(:create_table)
          .and_yield(table_definition)

        migration.create_bt_table(:test_models) { |_t| } # rubocop:disable Lint/EmptyBlock
      end

      it 'adds timestamps' do
        table_definition = double('TableDefinition')
        expect(table_definition).to receive(:integer).with(:lock_version, null: false, default: 0)
        expect(table_definition).to receive(:timestamps).with(null: false)

        expect(migration).to receive(:create_table)
          .and_yield(table_definition)

        migration.create_bt_table(:test_models) { |_t| } # rubocop:disable Lint/EmptyBlock
      end

      it 'yields block for additional columns' do
        block_called = false
        table_definition = double('TableDefinition',
                                  integer: nil,
                                  timestamps: nil)

        expect(migration).to receive(:create_table)
          .and_yield(table_definition)

        migration.create_bt_table(:test_models) do |t|
          block_called = true
          expect(t).to eq(table_definition)
        end

        expect(block_called).to be true
      end
    end

    describe '#create_bt_membership_table' do
      let(:table_definition) do
        double('TableDefinition',
               bt_references: nil,
               index: nil,
               integer: nil,
               timestamps: nil)
      end

      before do
        # Stub the create_bt_table method
        allow(migration).to receive(:create_bt_table)
          .and_yield(table_definition)
      end

      context 'with default table names' do
        it 'creates member reference with correct target table' do
          expect(table_definition).to receive(:bt_references)
            .with(:member,
                  hash_including(
                    null: false,
                    target_table: 'better_together_people'
                  ))

          migration.create_bt_membership_table(
            :person_platform_memberships,
            member_type: :person,
            joinable_type: :platform
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end

        it 'creates joinable reference with correct target table' do
          expect(table_definition).to receive(:bt_references)
            .with(:joinable,
                  hash_including(
                    null: false,
                    target_table: 'better_together_platforms'
                  ))

          migration.create_bt_membership_table(
            :person_platform_memberships,
            member_type: :person,
            joinable_type: :platform
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end

        it 'creates role reference' do
          expect(table_definition).to receive(:bt_references)
            .with(:role,
                  hash_including(
                    null: false,
                    target_table: :better_together_roles
                  ))

          migration.create_bt_membership_table(
            :person_platform_memberships,
            member_type: :person,
            joinable_type: :platform
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end

        it 'creates unique composite index' do
          expect(table_definition).to receive(:index)
            .with(%i[joinable_id member_id role_id],
                  hash_including(
                    unique: true,
                    name: 'unique_person_platform_membership_member_role'
                  ))

          migration.create_bt_membership_table(
            :person_platform_memberships,
            member_type: :person,
            joinable_type: :platform
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      context 'with custom table names' do
        it 'uses custom member table name' do
          expect(table_definition).to receive(:bt_references)
            .with(:member,
                  hash_including(
                    target_table: 'custom_members'
                  ))

          migration.create_bt_membership_table(
            :custom_memberships,
            member_type: :user,
            joinable_type: :organization,
            member_table_name: 'custom_members'
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end

        it 'uses custom joinable table name' do
          expect(table_definition).to receive(:bt_references)
            .with(:joinable,
                  hash_including(
                    target_table: 'custom_joinables'
                  ))

          migration.create_bt_membership_table(
            :custom_memberships,
            member_type: :user,
            joinable_type: :organization,
            joinable_table_name: 'custom_joinables'
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      context 'with custom id type' do
        it 'passes id type to create_bt_table' do
          expect(migration).to receive(:create_bt_table)
            .with(:test_memberships, hash_including(id: :bigint))
            .and_yield(table_definition)

          migration.create_bt_membership_table(
            :test_memberships,
            member_type: :person,
            joinable_type: :platform,
            id: :bigint
          ) { |_t| } # rubocop:disable Lint/EmptyBlock
        end
      end

      it 'creates index names with proper format' do
        expect(table_definition).to receive(:bt_references)
          .with(:member,
                hash_including(
                  index: { name: 'person_platform_membership_by_member' }
                ))

        expect(table_definition).to receive(:bt_references)
          .with(:joinable,
                hash_including(
                  index: { name: 'person_platform_membership_by_joinable' }
                ))

        expect(table_definition).to receive(:bt_references)
          .with(:role,
                hash_including(
                  index: { name: 'person_platform_membership_by_role' }
                ))

        migration.create_bt_membership_table(
          :person_platform_memberships,
          member_type: :person,
          joinable_type: :platform
        ) { |_t| } # rubocop:disable Lint/EmptyBlock
      end

      it 'yields block for additional columns' do
        block_called = false

        migration.create_bt_membership_table(
          :test_memberships,
          member_type: :person,
          joinable_type: :platform
        ) do |t|
          block_called = true
          expect(t).to eq(table_definition)
        end

        expect(block_called).to be true
      end
    end

    describe 'table naming conventions' do
      it 'properly handles prefix with trailing underscore' do
        expect(migration).to receive(:create_table)
          .with('better_together_test_models', id: :uuid)
          .and_yield(double('TableDefinition',
                            integer: nil,
                            timestamps: nil))

        migration.create_bt_table(:test_models, prefix: 'better_together_') { |_t| } # rubocop:disable Lint/EmptyBlock
      end

      it 'properly handles prefix without trailing underscore' do
        expect(migration).to receive(:create_table)
          .with('better_together_test_models', id: :uuid)
          .and_yield(double('TableDefinition',
                            integer: nil,
                            timestamps: nil))

        migration.create_bt_table(:test_models, prefix: 'better_together') { |_t| } # rubocop:disable Lint/EmptyBlock
      end
    end

    describe 'pluralization handling' do
      it 'pluralizes member_type for table name' do
        expect(table_definition = double('TableDefinition')).to receive(:bt_references)
          .with(:member,
                hash_including(
                  target_table: 'better_together_people'
                ))
        expect(table_definition).to receive(:bt_references).at_least(:once)
        expect(table_definition).to receive(:index)

        allow(migration).to receive(:create_bt_table)
          .and_yield(table_definition)

        migration.create_bt_membership_table(
          :test_memberships,
          member_type: :person,
          joinable_type: :platform
        ) { |_t| } # rubocop:disable Lint/EmptyBlock
      end

      it 'pluralizes joinable_type for table name' do
        expect(table_definition = double('TableDefinition')).to receive(:bt_references)
          .with(:joinable,
                hash_including(
                  target_table: 'better_together_platforms'
                ))
        expect(table_definition).to receive(:bt_references).at_least(:once)
        expect(table_definition).to receive(:index)

        allow(migration).to receive(:create_bt_table)
          .and_yield(table_definition)

        migration.create_bt_membership_table(
          :test_memberships,
          member_type: :person,
          joinable_type: :platform
        ) { |_t| } # rubocop:disable Lint/EmptyBlock
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength, RSpec/StubbedMock, RSpec/VerifiedDoubles, RSpec/RepeatedExample
