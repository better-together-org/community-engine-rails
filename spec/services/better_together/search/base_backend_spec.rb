# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::BaseBackend, type: :service do
  subject(:backend) { described_class.new }

  describe '#audit_report_labels' do
    it 'returns default label keys' do
      labels = backend.audit_report_labels
      expect(labels[:collection]).to eq('Search Stores')
      expect(labels[:identifier]).to eq('Store')
      expect(labels[:documents]).to eq('Searchable Records')
      expect(labels[:size]).to eq('Store Size')
    end
  end

  describe '#audit_capabilities' do
    it 'reports store_size and existence_checks as false by default' do
      caps = backend.audit_capabilities
      expect(caps[:store_size]).to be false
      expect(caps[:existence_checks]).to be false
    end
  end

  describe '#audit_search_mode' do
    let(:concrete_backend) do
      Class.new(described_class) do
        def backend_key = :database
      end.new
    end

    it 'returns the backend_key as a string' do
      expect(concrete_backend.audit_search_mode(double)).to eq('database')
    end
  end

  describe 'abstract interface methods' do
    no_arg_methods = %i[backend_key configured? available?]
    one_arg_methods = %i[search create_index ensure_index delete_index refresh_index
                         import_model index_exists? document_count index_stats index_record
                         delete_record]

    no_arg_methods.each do |method_name|
      it "raises NotImplementedError for zero-arg ##{method_name}" do
        expect { backend.public_send(method_name) }.to raise_error(NotImplementedError)
      end
    end

    one_arg_methods.each do |method_name|
      it "raises NotImplementedError for one-arg ##{method_name}" do
        expect { backend.public_send(method_name, double) }.to raise_error(NotImplementedError)
      end
    end
  end
end
