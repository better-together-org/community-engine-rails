# frozen_string_literal: true

require 'rails_helper'

# Explicitly load the file since it may not be autoloaded
require_relative '../../../lib/better_together/safe_class_resolver'

RSpec.describe BetterTogether::SafeClassResolver do
  describe '.resolve' do
    context 'with nil or blank candidate' do
      it 'returns nil for nil' do
        expect(described_class.resolve(nil, allowed: [String])).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.resolve('', allowed: [String])).to be_nil
      end

      it 'returns nil for blank string' do
        expect(described_class.resolve('  ', allowed: [String])).to be_nil
      end
    end

    context 'with valid class in allow-list' do
      it 'resolves class from string when in allow-list' do
        result = described_class.resolve('String', allowed: [String])
        expect(result).to eq(String)
      end

      it 'resolves class when allow-list contains class objects' do
        result = described_class.resolve('String', allowed: [String, Integer])
        expect(result).to eq(String)
      end

      it 'resolves class when allow-list contains string names' do
        result = described_class.resolve('String', allowed: %w[String Integer])
        expect(result).to eq(String)
      end

      it 'resolves namespaced class' do
        result = described_class.resolve(
          'BetterTogether::User',
          allowed: [BetterTogether::User]
        )
        expect(result).to eq(BetterTogether::User)
      end

      it 'resolves with fully qualified class name' do
        result = described_class.resolve(
          '::BetterTogether::User',
          allowed: ['::BetterTogether::User']
        )
        expect(result).to eq(BetterTogether::User)
      end
    end

    context 'with class not in allow-list' do
      it 'returns nil when class not in allow-list' do
        result = described_class.resolve('String', allowed: [Integer])
        expect(result).to be_nil
      end

      it 'returns nil when allow-list is empty' do
        result = described_class.resolve('String', allowed: [])
        expect(result).to be_nil
      end

      it 'returns nil for malicious input' do
        result = described_class.resolve('`rm -rf /`', allowed: [String])
        expect(result).to be_nil
      end
    end

    context 'with non-existent class name' do
      it 'returns nil when class does not exist even if in allow-list' do
        result = described_class.resolve('NonExistentClass', allowed: ['NonExistentClass'])
        expect(result).to be_nil
      end
    end

    context 'security: prevents unsafe constantize' do
      it 'does not allow arbitrary code execution' do
        malicious_input = 'File.delete("/tmp/test")'
        result = described_class.resolve(malicious_input, allowed: [String])
        expect(result).to be_nil
      end

      it 'does not allow eval-like behavior' do
        malicious_input = 'Kernel.system("echo hacked")'
        result = described_class.resolve(malicious_input, allowed: [String])
        expect(result).to be_nil
      end

      it 'only resolves exact class name matches' do
        result = described_class.resolve('String#upcase', allowed: [String])
        expect(result).to be_nil
      end
    end

    context 'with mixed allow-list types' do
      it 'handles mix of Class and String in allow-list' do
        result = described_class.resolve(
          'String',
          allowed: [Integer, 'String', 'Hash']
        )
        expect(result).to eq(String)
      end

      it 'handles symbols converted to strings' do
        result = described_class.resolve(
          'String',
          allowed: [:String]
        )
        expect(result).to eq(String)
      end
    end
  end

  describe '.resolve!' do
    context 'with valid class in allow-list' do
      it 'returns the resolved class' do
        result = described_class.resolve!('String', allowed: [String])
        expect(result).to eq(String)
      end

      it 'resolves namespaced class' do
        result = described_class.resolve!(
          'BetterTogether::User',
          allowed: [BetterTogether::User]
        )
        expect(result).to eq(BetterTogether::User)
      end
    end

    context 'with class not in allow-list' do
      it 'raises ArgumentError by default' do
        expect do
          described_class.resolve!('String', allowed: [Integer])
        end.to raise_error(ArgumentError, /Disallowed class: String/)
      end

      it 'raises custom error when specified' do
        expect do
          described_class.resolve!('String', allowed: [Integer], error_class: SecurityError)
        end.to raise_error(SecurityError, /Disallowed class: String/)
      end

      it 'includes the candidate in error message' do
        expect do
          described_class.resolve!('MaliciousClass', allowed: [])
        end.to raise_error(ArgumentError, /MaliciousClass/)
      end
    end

    context 'with nil or blank candidate' do
      it 'raises error for nil' do
        expect do
          described_class.resolve!(nil, allowed: [String])
        end.to raise_error(ArgumentError, /Disallowed class/)
      end

      it 'raises error for empty string' do
        expect do
          described_class.resolve!('', allowed: [String])
        end.to raise_error(ArgumentError)
      end
    end

    context 'with non-existent class' do
      it 'raises error when class does not exist' do
        expect do
          described_class.resolve!('NonExistentClass', allowed: ['NonExistentClass'])
        end.to raise_error(ArgumentError, /Disallowed class: NonExistentClass/)
      end
    end
  end

  describe 'real-world usage patterns' do
    context 'polymorphic association resolution' do
      it 'safely resolves polymorphic types' do
        allowed_types = [
          BetterTogether::Community,
          BetterTogether::Platform,
          BetterTogether::Person
        ]

        result = described_class.resolve(
          'BetterTogether::Community',
          allowed: allowed_types
        )
        expect(result).to eq(BetterTogether::Community)

        result = described_class.resolve(
          'BetterTogether::MaliciousClass',
          allowed: allowed_types
        )
        expect(result).to be_nil
      end
    end

    context 'concern inclusion validation' do
      it 'validates class is in approved list before including' do
        allowed_concerns = [
          'BetterTogether::Authorable',
          'BetterTogether::Creatable'
        ]

        # Valid concern
        result = described_class.resolve(
          'BetterTogether::Authorable',
          allowed: allowed_concerns
        )
        expect(result).to be_a(Module)

        # Invalid concern
        result = described_class.resolve(
          'BetterTogether::UnknownConcern',
          allowed: allowed_concerns
        )
        expect(result).to be_nil
      end
    end
  end
end
