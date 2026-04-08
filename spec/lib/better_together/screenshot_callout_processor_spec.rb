# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'vips'

module BetterTogether # :nodoc:
  RSpec.describe ScreenshotCalloutProcessor do
    describe '.process' do
      it 'adds an annotated callout overlay and returns placement metadata' do
        Dir.mktmpdir do |dir|
          image_path = File.join(dir, 'callout-test.png')
          Vips::Image.black(1200, 800).new_from_image([255, 255, 255]).write_to_file(image_path)

          processed = described_class.process(
            image_path,
            callouts: [
              {
                selector: '#participant-picker',
                title: 'Scoped conversation discovery',
                bullets: ['Available in picker: Platform Steward, Opted In O\'Reilly', 'Withheld from picker: Regular Member'],
                target: { x: 140, y: 210, width: 320, height: 130 }
              }
            ]
          )

          expect(processed.size).to eq(1)
          expect(processed.first[:placement][:side]).to eq('right')
          expect(File.stat(image_path).mode & 0o777).to eq(0o644)

          image = Vips::Image.new_from_file(image_path)
          pixel = image.crop(processed.first[:placement][:x].to_i + 8, processed.first[:placement][:y].to_i + 8, 1, 1).to_a.flatten
          expect(pixel).not_to eq([255.0, 255.0, 255.0, 255.0])
        end
      end

      it 'avoids covering the broader target container when provided' do
        Dir.mktmpdir do |dir|
          image_path = File.join(dir, 'callout-avoid-container.png')
          Vips::Image.black(1440, 900).new_from_image([255, 255, 255]).write_to_file(image_path)

          processed = described_class.process(
            image_path,
            callouts: [
              {
                selector: '.card .badge.text-bg-warning',
                title: 'Upload remains held before release',
                bullets: ['Place the note in adjacent whitespace instead of over the upload card.'],
                target: { x: 180, y: 130, width: 96, height: 36 },
                avoid: { x: 120, y: 80, width: 540, height: 320 }
              }
            ]
          )

          placement = processed.first[:placement]
          avoid = processed.first[:avoid]

          expect(placement[:x]).to be > avoid[:right]
          expect(placement[:side]).to eq('right')
        end
      end
    end
  end
end
