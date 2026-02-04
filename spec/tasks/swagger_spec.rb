# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# rubocop:disable RSpec/DescribeClass, RSpec/SpecFilePathFormat
RSpec.describe 'swagger rake tasks', type: :task do
  before do
    Rake.application = Rake::Application.new
    # Load the rake task file directly
    load BetterTogether::Engine.root.join('lib/tasks/swagger.rake')
    Rake::Task.define_task(:environment)
  end

  let(:swagger_path) { BetterTogether::Engine.root.join('swagger/v1/swagger.yaml') }

  describe 'swagger:generate' do
    let(:task) { Rake::Task['swagger:generate'] }

    before do
      task.reenable
      # Clean up any existing swagger file
      FileUtils.rm_f(swagger_path)
    end

    it 'generates swagger documentation' do
      # Mock the rswag task to avoid running full spec suite
      allow(Rake::Task).to receive(:[]).and_call_original
      allow(Rake::Task).to receive(:[]).with('app:rswag:specs:swaggerize')
                                       .and_return(double(invoke: true))

      expect { task.invoke }.to output(/Generating Swagger documentation/).to_stdout
    end

    it 'displays the correct environment and base URL' do
      expect { task.invoke }.to output(/Base URL: #{Regexp.escape(BetterTogether.base_url)}/).to_stdout
    end

    it 'outputs success message after generation' do
      expect { task.invoke }.to output(/✓ Swagger documentation generated/).to_stdout
    end
  end

  describe 'swagger:validate', skip: 'Requires full Rails environment and generated swagger.yaml file' do
    # NOTE: These tests are skipped because swagger:validate task
    # requires full Rails environment and swagger.yaml to exist.
    # Integration tests cover this functionality more appropriately.
    let(:task) { Rake::Task['swagger:validate'] }

    before do
      task.reenable
    end

    context 'when swagger file does not exist' do
      before do
        FileUtils.rm_f(swagger_path)
      end

      it 'exits with error and helpful message' do
        expect { task.invoke }.to output(/✗ Swagger documentation not found/).to_stdout
                                                                             .and raise_error(SystemExit)
      end
    end

    context 'when swagger file exists' do
      let(:current_base_url) { BetterTogether.base_url }

      # rubocop:disable RSpec/NestedGroups
      context 'with current server URL' do
        before do
          swagger_content = {
            'openapi' => '3.0.1',
            'info' => { 'title' => 'Test API', 'version' => 'v1' },
            'servers' => [
              { 'url' => current_base_url, 'description' => 'Current server' }
            ],
            'paths' => {}
          }
          FileUtils.mkdir_p(File.dirname(swagger_path))
          File.write(swagger_path, swagger_content.to_yaml)
        end

        after do
          FileUtils.rm_f(swagger_path)
        end

        it 'validates successfully' do
          expect { task.invoke }.to output(/✓ Swagger documentation is current/).to_stdout
        end

        it 'displays the current base URL' do
          expect { task.invoke }.to output(/Base URL: #{Regexp.escape(current_base_url)}/).to_stdout
        end
      end
      # rubocop:enable RSpec/NestedGroups

      # rubocop:disable RSpec/NestedGroups
      context 'with outdated server URL' do
        before do
          swagger_content = {
            'openapi' => '3.0.1',
            'info' => { 'title' => 'Test API', 'version' => 'v1' },
            'servers' => [
              { 'url' => 'http://old-server.example.com', 'description' => 'Old server' }
            ],
            'paths' => {}
          }
          FileUtils.mkdir_p(File.dirname(swagger_path))
          File.write(swagger_path, swagger_content.to_yaml)
        end

        after do
          FileUtils.rm_f(swagger_path)
        end

        it 'exits with error indicating update needed' do
          expect { task.invoke }.to output(/✗ Swagger documentation may be outdated/).to_stdout
                                                                                     .and raise_error(SystemExit)
        end

        it 'displays expected and found URLs' do
          output = capture_stdout do
            task.invoke
          rescue StandardError
            SystemExit
          end
          expect(output).to match(/Expected URL: #{Regexp.escape(current_base_url)}/)
          expect(output).to match(%r{Found URLs: http://old-server\.example\.com})
        end

        it 'suggests running generation task' do
          expect { task.invoke }.to output(/Run: rake swagger:generate/).to_stdout
                                                                        .and raise_error(SystemExit)
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end
  end

  # Helper method to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    begin
      yield
    ensure
      output = $stdout.string
      $stdout = original_stdout
    end
    output
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/SpecFilePathFormat
