# frozen_string_literal: true

require 'rails_helper'

# Load the Mobility backend explicitly
require Rails.root.join('../../lib/mobility/backends/attachments')

RSpec.describe Mobility::Backends::Attachments do
  describe 'module structure' do
    it 'is a Module' do
      expect(described_class).to be_a(Module)
    end

    it 'extends ActiveSupport::Concern' do
      # Check that the module uses ActiveSupport::Concern
      expect(described_class.ancestors).to include(ActiveSupport::Concern)
    end
  end

  describe 'included class methods' do
    let(:test_class) do
      Class.new do
        include Mobility::Backends::Attachments

        def self.name
          'TestModel'
        end
      end
    end

    it 'provides valid_keys class method' do
      expect(test_class).to respond_to(:valid_keys)
    end

    it 'valid_keys returns an array' do
      expect(test_class.valid_keys).to be_an(Array)
    end

    it 'valid_keys includes :fallback' do
      expect(test_class.valid_keys).to include(:fallback)
    end

    it 'provides setup class method' do
      expect(test_class).to respond_to(:setup)
    end

    it 'setup can be called without error' do
      expect { test_class.setup }.not_to raise_error
    end
  end

  describe 'module singleton methods' do
    it 'responds to setup' do
      expect(described_class).to respond_to(:setup)
    end

    it 'setup can be called' do
      expect { described_class.setup }.not_to raise_error
    end
  end

  describe 'Mobility backend pattern compliance' do
    it 'defines ClassMethods module' do
      expect(described_class.const_defined?(:ClassMethods)).to be(true)
    end

    it 'ClassMethods defines valid_keys' do
      class_methods = described_class.const_get(:ClassMethods)
      expect(class_methods.instance_methods).to include(:valid_keys)
    end

    it 'ClassMethods defines setup' do
      class_methods = described_class.const_get(:ClassMethods)
      expect(class_methods.instance_methods).to include(:setup)
    end
  end

  describe 'backend configuration' do
    let(:backend_class) do
      Class.new do
        include Mobility::Backends::Attachments
      end
    end

    it 'only includes fallback as valid key' do
      expect(backend_class.valid_keys).to eq([:fallback])
    end
  end
end
