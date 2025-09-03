# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seed, 'Security Features', type: :model do
  describe 'Security Configuration' do
    it 'defines maximum file size limit' do
      expect(described_class::MAX_FILE_SIZE).to eq(10.megabytes)
    end

    it 'defines permitted YAML classes' do
      expect(described_class::PERMITTED_YAML_CLASSES).to include(Time, Date, DateTime, Symbol)
    end

    it 'defines allowed seed directories' do
      expect(described_class::ALLOWED_SEED_DIRECTORIES).to include('config/seeds')
    end
  end

  describe '.validate_file_path!' do
    context 'with allowed paths' do
      it 'allows files within config/seeds directory' do
        path = Rails.root.join('config', 'seeds', 'test_seed.yml').to_s
        expect { described_class.validate_file_path!(path) }.not_to raise_error
      end
    end

    context 'with disallowed paths' do
      it 'rejects paths outside allowed directories' do
        path = '/tmp/malicious_seed.yml'
        expect { described_class.validate_file_path!(path) }
          .to raise_error(SecurityError, /not within allowed seed directories/)
      end

      it 'rejects paths with path traversal attempts' do
        path = 'config/seeds/../../../malicious.yml'
        expect { described_class.validate_file_path!(path) }
          .to raise_error(SecurityError, /path traversal characters/)
      end

      it 'rejects absolute paths outside allowed directories' do
        path = '/etc/passwd'
        expect { described_class.validate_file_path!(path) }
          .to raise_error(SecurityError, /not within allowed seed directories/)
      end
    end
  end

  describe '.validate_file_size!' do
    let(:temp_file) { Tempfile.new(['test_seed', '.yml']) }

    after { temp_file.unlink }

    context 'with acceptable file size' do
      it 'allows files under the size limit' do
        temp_file.write('a' * 1024) # 1KB file
        temp_file.close
        expect { described_class.validate_file_size!(temp_file.path) }.not_to raise_error
      end
    end

    context 'with oversized files' do
      it 'rejects files over the size limit' do
        # Mock a large file size without actually creating it
        allow(File).to receive(:size).with(temp_file.path).and_return(15.megabytes)
        expect { described_class.validate_file_size!(temp_file.path) }
          .to raise_error(SecurityError, /exceeds maximum allowed size/)
      end
    end
  end

  describe '.safe_load_yaml_file' do
    let(:temp_file) { Tempfile.new(['test_seed', '.yml']) }

    after { temp_file.unlink }

    context 'with safe YAML content' do
      it 'loads valid YAML with permitted classes' do
        yaml_content = {
          'better_together' => {
            'version' => '1.0',
            'seed' => {
              'type' => 'BetterTogether::Seed',
              'identifier' => 'test_seed',
              'created_by' => 'Test',
              'created_at' => Time.now.iso8601,
              'description' => 'Test seed',
              'origin' => { 'license' => 'MIT' }
            },
            'data' => 'test'
          }
        }.to_yaml

        temp_file.write(yaml_content)
        temp_file.close

        result = described_class.safe_load_yaml_file(temp_file.path)
        expect(result).to be_a(Hash)
        expect(result['better_together']['version']).to eq('1.0')
      end
    end

    context 'with dangerous YAML content' do
      it 'rejects YAML with disallowed classes' do
        # Create YAML that would instantiate a dangerous class
        yaml_content = '--- !ruby/object:File {}'
        temp_file.write(yaml_content)
        temp_file.close

        expect { described_class.safe_load_yaml_file(temp_file.path) }
          .to raise_error(SecurityError, /Unsafe class detected/)
      end

      it 'rejects YAML with aliases' do
        yaml_content = <<~YAML
          ---
          default: &default
            name: test
          production:
            <<: *default
        YAML
        temp_file.write(yaml_content)
        temp_file.close

        expect { described_class.safe_load_yaml_file(temp_file.path) }
          .to raise_error(SecurityError, /aliases are not permitted/)
      end
    end
  end

  describe '.validate_seed_structure!' do
    let(:valid_seed_data) do
      {
        'better_together' => {
          'version' => '1.0',
          'seed' => {
            'type' => 'BetterTogether::Seed',
            'identifier' => 'test_seed',
            'created_by' => 'Test',
            'created_at' => Time.now.iso8601,
            'description' => 'Test seed',
            'origin' => { 'license' => 'MIT' }
          }
        }
      }
    end

    context 'with valid structure' do
      it 'validates correct seed structure' do
        expect { described_class.validate_seed_structure!(valid_seed_data, 'better_together') }
          .not_to raise_error
      end
    end

    context 'with invalid structure' do
      it 'rejects non-hash data' do
        expect { described_class.validate_seed_structure!('invalid', 'better_together') }
          .to raise_error(ArgumentError, /must be a hash/)
      end

      it 'rejects data missing root key' do
        data = { 'wrong_key' => {} }
        expect { described_class.validate_seed_structure!(data, 'better_together') }
          .to raise_error(ArgumentError, /missing root key/)
      end

      it 'rejects data missing version field' do
        data = { 'better_together' => { 'seed' => {} } }
        expect { described_class.validate_seed_structure!(data, 'better_together') }
          .to raise_error(ArgumentError, /missing required field: version/)
      end

      it 'rejects data missing seed field' do
        data = { 'better_together' => { 'version' => '1.0' } }
        expect { described_class.validate_seed_structure!(data, 'better_together') }
          .to raise_error(ArgumentError, /missing required field: seed/)
      end

      it 'rejects invalid version format' do
        data = valid_seed_data.deep_dup
        data['better_together']['version'] = 'invalid'
        expect { described_class.validate_seed_structure!(data, 'better_together') }
          .to raise_error(ArgumentError, /Invalid version format/)
      end

      %w[type identifier created_by created_at description origin].each do |required_field|
        it "rejects seed metadata missing #{required_field}" do
          data = valid_seed_data.deep_dup
          data['better_together']['seed'].delete(required_field)
          expect { described_class.validate_seed_structure!(data, 'better_together') }
            .to raise_error(ArgumentError, /missing required field: #{required_field}/)
        end
      end
    end
  end

  describe '.import_with_validation' do
    let(:valid_seed_data) do
      {
        'better_together' => {
          'version' => '1.0',
          'seed' => {
            'type' => 'BetterTogether::Seed',
            'identifier' => 'secure_test_seed',
            'created_by' => 'SecurityTest',
            'created_at' => Time.now.iso8601,
            'description' => 'A secure test seed',
            'origin' => {
              'contributors' => [],
              'platforms' => [],
              'license' => 'MIT',
              'usage_notes' => 'Test only'
            }
          },
          'test_data' => 'secure_value'
        }
      }
    end

    context 'with valid data' do
      it 'successfully imports valid seed data' do
        result = described_class.import_with_validation(valid_seed_data)
        expect(result).to be_a(described_class)
        expect(result.identifier).to eq('secure_test_seed')
        expect(result.created_by).to eq('SecurityTest')
      end

      it 'wraps import in a database transaction' do
        expect(described_class).to receive(:transaction).and_call_original
        described_class.import_with_validation(valid_seed_data)
      end
    end

    context 'with invalid data' do
      it 'rejects malformed seed data' do
        malformed_data = { 'wrong_structure' => 'invalid' }
        expect { described_class.import_with_validation(malformed_data) }
          .to raise_error(RuntimeError, /Invalid data format in seed.*missing root key/)
      end

      it 'handles validation errors gracefully' do
        invalid_data = valid_seed_data.deep_dup
        # Remove required field to trigger validation error
        invalid_data['better_together']['seed'].delete('identifier')
        expect { described_class.import_with_validation(invalid_data) }
          .to raise_error(RuntimeError, /Invalid data format.*missing required field.*identifier/)
      end
    end
  end

  describe 'End-to-end security test' do
    let(:secure_seed_file) { Rails.root.join('config', 'seeds', 'security_test.yml') }
    let(:seed_content) do
      {
        'better_together' => {
          'version' => '1.0',
          'seed' => {
            'type' => 'BetterTogether::Seed',
            'identifier' => 'e2e_security_test',
            'created_by' => 'E2ESecurityTest',
            'created_at' => Time.now.iso8601,
            'description' => 'End-to-end security test seed',
            'origin' => {
              'contributors' => [],
              'platforms' => [],
              'license' => 'MIT',
              'usage_notes' => 'Security testing'
            }
          },
          'secure_data' => { 'value' => 'protected' }
        }
      }.to_yaml
    end

    before do
      FileUtils.mkdir_p(File.dirname(secure_seed_file))
      File.write(secure_seed_file, seed_content)
    end

    after do
      FileUtils.rm_f(secure_seed_file)
    end

    it 'successfully loads a secure seed file end-to-end' do
      result = described_class.load_seed(secure_seed_file.to_s)
      expect(result).to be_a(described_class)
      expect(result.identifier).to eq('e2e_security_test')
      expect(result.payload[:secure_data][:value]).to eq('protected')
    end
  end
end
