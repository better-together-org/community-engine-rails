# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Engine do
    describe 'autoload configuration' do
      let(:engine_root) { described_class.root.to_s }

      it 'autoloads from lib without registering nested namespaces as Zeitwerk roots' do
        expect(described_class.config.autoload_paths).to include("#{engine_root}/lib")
        expect(described_class.config.autoload_paths).not_to include("#{engine_root}/lib/better_together/mcp")
      end

      it 'eager loads lib classes' do
        expect(described_class.config.eager_load_paths).to include("#{engine_root}/lib")
      end
    end

    describe 'migration paths' do
      it 'includes engine migrations in the dummy app' do
        engine_migrations = described_class.root.join('db', 'migrate').to_s

        expect(Rails.application.config.paths['db/migrate'].expanded).to include(engine_migrations)
      end
    end
  end
end
