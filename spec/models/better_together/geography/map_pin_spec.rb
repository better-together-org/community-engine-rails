# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Geography
    RSpec.describe MapPin do
      describe '.sanitize' do
        it 'keeps a valid pin' do
          pin = { color: '#2a7', shape: 'rounded', size: 'lg',
                  icons: ['fa-landmark', { icon: 'fa-star', color: 'gold', style: 'far', scale: 0.6 }] }

          expect(described_class.sanitize(pin)).to eq(
            color: '#2a7', shape: 'rounded', size: 'lg',
            icons: [{ icon: 'fa-landmark', style: 'fas' }, { icon: 'fa-star', style: 'far', color: 'gold', scale: 0.6 }]
          )
        end

        it 'drops colors that are not plain CSS colors' do
          expect(described_class.sanitize(color: 'red;background:url(x)', icons: ['fa-star'])).to eq(
            icons: [{ icon: 'fa-star', style: 'fas' }]
          )
        end

        it 'drops icon names that are not Font Awesome classes' do
          pin = described_class.sanitize(icons: ['fa-star" onclick="x', '<i>', 'star', 'fa-ok'])

          expect(pin[:icons].pluck(:icon)).to eq(['fa-ok'])
        end

        it 'drops unknown shapes, sizes and styles' do
          pin = described_class.sanitize(shape: 'blob', size: 'huge', icons: [{ icon: 'fa-star', style: 'evil' }])

          expect(pin).to eq(icons: [{ icon: 'fa-star', style: 'fas' }])
        end

        it 'limits the stack to four icons and the scale to a sane range' do
          icons = (1..6).map { |i| { icon: "fa-#{i}x", scale: i == 1 ? 9 : 1 } }
          pin = described_class.sanitize(icons:)

          expect([pin[:icons].size, pin[:icons].first.key?(:scale)]).to eq([4, false])
        end

        it 'returns nil when nothing usable is given' do
          expect([described_class.sanitize(nil), described_class.sanitize(shape: 'blob')]).to eq([nil, nil])
        end
      end

      describe '.point' do
        it 'reads the older color and icon keys as a one icon pin' do
          point = described_class.point(lat: 1, lng: 2, color: '#0d6efd', icon: 'fa-newspaper')

          expect(point[:pin]).to eq(color: '#0d6efd', icons: [{ icon: 'fa-newspaper', style: 'fas' }])
        end

        it 'prefers its own pin and keeps the other keys' do
          point = described_class.point(lat: 1, lng: 2, label: 'x', color: 'red', pin: { shape: 'square' })

          expect(point).to include(lat: 1, label: 'x', pin: { shape: 'square' })
        end

        it 'adds no pin to a plain point' do
          expect(described_class.point(lat: 1, lng: 2)).to eq(lat: 1, lng: 2)
        end
      end

      describe '.type' do
        it 'keeps a clean pin on a type' do
          type = described_class.type(key: 'Post', label: 'Posts', color: '#0d6efd', pin: { icons: ['fa-newspaper'] })

          expect(type[:pin]).to eq(icons: [{ icon: 'fa-newspaper', style: 'fas' }])
        end
      end
    end
  end
end
