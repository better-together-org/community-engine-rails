# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'tempfile'
require 'vips'

module BetterTogether # :nodoc:
  module ScreenshotCalloutProcessor # :nodoc:
    extend self

    BOX_MARGIN = 24
    TARGET_GAP = 20
    BOX_PADDING = 18
    TITLE_FONT_SIZE = 26
    BODY_FONT_SIZE = 20
    TITLE_LINE_HEIGHT = 32
    BODY_LINE_HEIGHT = 26
    MAX_BOX_WIDTH = 380
    MIN_BOX_WIDTH = 220

    def process(image_path, callouts:)
      prepared = prepare_callouts(callouts, image_path:)
      return [] if prepared.empty?

      base = Vips::Image.new_from_file(image_path.to_s, access: :sequential)
      base = base.bandjoin(255) unless base.has_alpha?
      overlay = Vips::Image.svgload_buffer(build_overlay_svg(base.width, base.height, prepared))
      write_processed_image(base.composite2(overlay, :over), image_path)
      prepared
    end

    private

    def prepare_callouts(callouts, image_path:)
      image = Vips::Image.new_from_file(image_path.to_s, access: :sequential)
      Array(callouts).filter_map do |callout|
        normalized = normalize_callout(callout)
        target = clip_target(normalized[:target], image.width, image.height)
        next unless target

        placement = best_placement(target, image.width, image.height, normalized[:title], normalized[:bullets])
        normalized.merge(target:, placement:)
      end
    end

    def normalize_callout(callout)
      target = symbolize_hash(callout[:target] || callout['target'])
      {
        selector: callout[:selector] || callout['selector'],
        title: callout[:title] || callout['title'],
        bullets: Array(callout[:bullets] || callout['bullets']).map(&:to_s),
        target:
      }
    end

    def symbolize_hash(hash)
      hash.to_h.transform_keys(&:to_sym)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def clip_target(target, image_width, image_height)
      x = [target[:x].to_f, 0].max
      y = [target[:y].to_f, 0].max
      width = [target[:width].to_f, image_width - x].min
      height = [target[:height].to_f, image_height - y].min
      return if width <= 0 || height <= 0

      {
        x:,
        y:,
        width:,
        height:,
        right: x + width,
        bottom: y + height,
        center_x: x + (width / 2.0),
        center_y: y + (height / 2.0)
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def best_placement(target, image_width, image_height, title, bullets)
      box_width = (image_width * (image_width < 700 ? 0.54 : 0.28)).clamp(MIN_BOX_WIDTH, MAX_BOX_WIDTH)
      box_height = estimate_box_height(box_width, title, bullets)

      candidates = [
        placement_candidate(
          side: :right,
          position: { x: target[:right] + TARGET_GAP, y: target[:center_y] - (box_height / 2.0) },
          box: { width: box_width, height: box_height },
          image: { width: image_width, height: image_height },
          target:,
          free_space: image_width - target[:right]
        ),
        placement_candidate(
          side: :left,
          position: { x: target[:x] - box_width - TARGET_GAP, y: target[:center_y] - (box_height / 2.0) },
          box: { width: box_width, height: box_height },
          image: { width: image_width, height: image_height },
          target:,
          free_space: target[:x]
        ),
        placement_candidate(
          side: :below,
          position: { x: target[:center_x] - (box_width / 2.0), y: target[:bottom] + TARGET_GAP },
          box: { width: box_width, height: box_height },
          image: { width: image_width, height: image_height },
          target:,
          free_space: image_height - target[:bottom]
        ),
        placement_candidate(
          side: :above,
          position: { x: target[:center_x] - (box_width / 2.0), y: target[:y] - box_height - TARGET_GAP },
          box: { width: box_width, height: box_height },
          image: { width: image_width, height: image_height },
          target:,
          free_space: target[:y]
        )
      ].compact

      candidates.max_by { |candidate| candidate[:score] } || fallback_placement(box_width, box_height, image_width, image_height, target)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
    def placement_candidate(side:, position:, box:, image:, target:, free_space:)
      clamped_x = clamp(position[:x], BOX_MARGIN, image[:width] - box[:width] - BOX_MARGIN)
      clamped_y = clamp(position[:y], BOX_MARGIN, image[:height] - box[:height] - BOX_MARGIN)
      overlap = rect_overlap?(
        { x: clamped_x, y: clamped_y, width: box[:width], height: box[:height] },
        { x: target[:x] - 8, y: target[:y] - 8, width: target[:width] + 16, height: target[:height] + 16 }
      )
      return if overlap

      {
        side: side.to_s,
        x: clamped_x.round(2),
        y: clamped_y.round(2),
        width: box[:width].round(2),
        height: box[:height].round(2),
        score: free_space
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists

    def fallback_placement(width, height, image_width, image_height, target)
      {
        side: 'floating',
        x: clamp(target[:right] + TARGET_GAP, BOX_MARGIN, image_width - width - BOX_MARGIN).round(2),
        y: clamp(target[:bottom] + TARGET_GAP, BOX_MARGIN, image_height - height - BOX_MARGIN).round(2),
        width: width.round(2),
        height: height.round(2)
      }
    end

    # rubocop:disable Metrics/AbcSize
    def rect_overlap?(source_rect, target_rect)
      source_rect[:x] < (target_rect[:x] + target_rect[:width]) &&
        (source_rect[:x] + source_rect[:width]) > target_rect[:x] &&
        source_rect[:y] < (target_rect[:y] + target_rect[:height]) &&
        (source_rect[:y] + source_rect[:height]) > target_rect[:y]
    end
    # rubocop:enable Metrics/AbcSize

    def estimate_box_height(box_width, title, bullets)
      title_lines = wrap_text(title.to_s, chars_per_line(box_width, TITLE_FONT_SIZE)).size
      bullet_lines = bullets.flat_map { |bullet| wrap_text("• #{bullet}", chars_per_line(box_width, BODY_FONT_SIZE)) }.size
      (BOX_PADDING * 2) + (title_lines * TITLE_LINE_HEIGHT) + 12 + (bullet_lines * BODY_LINE_HEIGHT)
    end

    def chars_per_line(box_width, font_size)
      [((box_width - (BOX_PADDING * 2)) / (font_size * 0.58)).floor, 18].max
    end

    def wrap_text(text, max_chars)
      return [''] if text.blank?

      text.split(/\s+/).each_with_object(['']) do |word, lines|
        candidate = [lines.last, word].reject(&:blank?).join(' ')
        if candidate.length <= max_chars
          lines[-1] = candidate
        else
          lines << word
        end
      end
    end

    def build_overlay_svg(image_width, image_height, callouts)
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{image_width}" height="#{image_height}" viewBox="0 0 #{image_width} #{image_height}">
          #{callouts.map { |callout| callout_svg(callout) }.join("\n")}
        </svg>
      SVG
    end

    # rubocop:disable Metrics/AbcSize
    def callout_svg(callout)
      target = callout[:target]
      placement = callout[:placement]
      start_point, end_point = connector_points(target, placement)

      <<~SVG
        <g class="docs-callout">
          <rect x="#{target[:x]}" y="#{target[:y]}" width="#{target[:width]}" height="#{target[:height]}"
                rx="12" fill="rgba(13, 110, 253, 0.12)" stroke="#0d6efd" stroke-width="4" />
          <path d="M #{start_point[:x]} #{start_point[:y]} L #{end_point[:x]} #{end_point[:y]}"
                stroke="#0d6efd" stroke-width="4" stroke-linecap="round" fill="none" />
          <circle cx="#{start_point[:x]}" cy="#{start_point[:y]}" r="6" fill="#0d6efd" />
          <rect x="#{placement[:x]}" y="#{placement[:y]}" width="#{placement[:width]}" height="#{placement[:height]}"
                rx="18" fill="rgba(248, 251, 255, 0.96)" stroke="#0d6efd" stroke-width="4" />
          #{callout_text_svg(callout)}
        </g>
      SVG
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize
    def connector_points(target, placement)
      case placement[:side]
      when 'right'
        [{ x: target[:right], y: target[:center_y] }, { x: placement[:x], y: placement[:y] + (placement[:height] / 2.0) }]
      when 'left'
        [{ x: target[:x], y: target[:center_y] }, { x: placement[:x] + placement[:width], y: placement[:y] + (placement[:height] / 2.0) }]
      when 'above'
        [{ x: target[:center_x], y: target[:y] }, { x: placement[:x] + (placement[:width] / 2.0), y: placement[:y] + placement[:height] }]
      else
        [{ x: target[:center_x], y: target[:bottom] }, { x: placement[:x] + (placement[:width] / 2.0), y: placement[:y] }]
      end
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def callout_text_svg(callout)
      placement = callout[:placement]
      x = placement[:x] + BOX_PADDING
      y = placement[:y] + BOX_PADDING + TITLE_FONT_SIZE
      title_lines = wrap_text(callout[:title], chars_per_line(placement[:width], TITLE_FONT_SIZE))
      body_lines = callout[:bullets].flat_map { |bullet| wrap_text("• #{bullet}", chars_per_line(placement[:width], BODY_FONT_SIZE)) }

      lines = []
      title_lines.each_with_index do |line, index|
        lines << %(
          <tspan x="#{x}" y="#{y + (index * TITLE_LINE_HEIGHT)}" font-size="#{TITLE_FONT_SIZE}" font-weight="700">
            #{escape_text(line)}
          </tspan>
        ).squish
      end

      body_start_y = y + (title_lines.size * TITLE_LINE_HEIGHT) + 12
      body_lines.each_with_index do |line, index|
        lines << %(
          <tspan x="#{x}" y="#{body_start_y + (index * BODY_LINE_HEIGHT)}" font-size="#{BODY_FONT_SIZE}" font-weight="500">
            #{escape_text(line)}
          </tspan>
        ).squish
      end

      %(<text fill="#082c61" font-family="Inter, Arial, sans-serif">#{lines.join}</text>)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def escape_text(text)
      ERB::Util.html_escape(text.to_s)
    end

    def clamp(value, min, max)
      value.clamp(min, max)
    end

    def write_processed_image(image, image_path)
      Tempfile.create(['docs-callout', '.png'], File.dirname(image_path.to_s)) do |file|
        image.write_to_file(file.path)
        FileUtils.mv(file.path, image_path.to_s)
      end
    end
  end
end
