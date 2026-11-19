# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/block/block_generator')

RSpec.describe BetterTogether::Generators::BlockGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-block-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    FileUtils.mkdir_p(File.join(tmp_dir, 'app/resources/better_together/api/v1'))
    File.write(File.join(tmp_dir, 'app/resources/better_together/api/v1/block_resource.rb'),
               "      VideoBlockResource          = BlockResource\n")
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  before { run_generator(%w[testimonial author:string --translatable=quote:text --icon=comment]) }

  it 'creates the model with translated and stored attributes' do
    assert_file 'app/models/better_together/content/testimonial_block.rb' do |content|
      expect(content).to include('class TestimonialBlock < Block', 'translates :quote, type: :text',
                                 'store_attributes :content_data', 'validates :quote, presence: true',
                                 'super + %i[quote author]')
    end
  end

  it 'creates the four view partials with the chosen icon' do
    assert_file 'app/views/better_together/content/blocks/_testimonial_block.html.erb', /locals: \(testimonial_block:\)/
    assert_file 'app/views/better_together/content/blocks/fields/_testimonial_block.html.erb', /translatable_text_field/
    assert_file 'app/views/better_together/content/blocks/new/_testimonial_block.html.erb', /fa-comment/
    assert_file 'app/views/better_together/content/page_blocks/block_types/_testimonial_block.html.erb', /fa-comment/
  end

  it 'creates four locale files, a factory and a spec' do
    %w[en es fr uk].each { |l| assert_file "config/locales/testimonial_block.#{l}.yml", /^#{l}:/ }
    assert_file 'spec/factories/better_together/content/testimonial_block.rb', /factory :content_testimonial_block/
    assert_file 'spec/models/better_together/content/testimonial_block_spec.rb'
  end

  it 'registers the JSON:API resource alias' do
    assert_file 'app/resources/better_together/api/v1/block_resource.rb', /TestimonialBlockResource = BlockResource/
  end

  it 'generates syntactically valid Ruby' do
    Dir[File.join(destination_root, '**/*.rb')].each do |path|
      expect { RubyVM::InstructionSequence.compile(File.read(path)) }.not_to raise_error, path
    end
  end
end
