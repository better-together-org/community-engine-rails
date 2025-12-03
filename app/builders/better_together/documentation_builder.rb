# frozen_string_literal: true

# app/builders/better_together/documentation_builder.rb

module BetterTogether
  # Builds documentation navigation from markdown files in the docs/ directory
  class DocumentationBuilder < Builder # rubocop:todo Metrics/ClassLength
    class << self
      def build # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        I18n.with_locale(:en) do
          entries = documentation_entries
          return if entries.blank?

          area = if (existing_area = ::BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation'))
                   existing_area.navigation_items.delete_all
                   existing_area.update!(name: 'Documentation', visible: true, protected: true)
                   existing_area
                 else
                   ::BetterTogether::NavigationArea.create! do |area|
                     area.name = 'Documentation'
                     area.slug = 'documentation'
                     area.visible = true
                     area.protected = true
                   end
                 end

          entries.each_with_index do |entry, index|
            create_documentation_navigation_item(area, entry, index)
          end

          area.reload.save!
        end
      end

      private

      def documentation_entries
        root = documentation_root
        return [] unless root.directory?

        build_documentation_entries(root)
      end

      def build_documentation_entries(current_path) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        documentation_child_paths(current_path).filter_map do |child|
          if child.directory?
            children = build_documentation_entries(child)
            default_path = default_documentation_file(child)
            next if children.blank? && default_path.blank?

            {
              type: :directory,
              title: documentation_title(child.basename.to_s),
              slug: documentation_slug(child),
              default_path: default_path,
              children: children
            }
          elsif markdown_file?(child)
            {
              type: :file,
              title: documentation_title(child.basename.sub_ext('').to_s),
              slug: documentation_slug(child),
              path: documentation_relative_path(child),
              children: []
            }
          end
        end
      end

      def documentation_child_paths(path)
        Dir.children(path).sort.map { |child| path.join(child) }.select do |child_path|
          next false if child_path.basename.to_s.start_with?('.')

          child_path.directory? || markdown_file?(child_path)
        end
      end

      def markdown_file?(path)
        path.file? && path.extname.casecmp('.md').zero?
      end

      def create_documentation_navigation_item(area, entry, position, parent: nil) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        attributes = {
          navigation_area: area,
          title_en: entry[:title],
          position: position,
          visible: true,
          protected: true,
          parent:
        }
        attributes[:identifier] = entry[:slug] if entry[:slug].present?

        if entry[:type] == :directory
          attributes[:item_type] = 'dropdown'
          if entry[:default_path].present?
            attributes[:linkable] = documentation_page_for(entry[:title], entry[:default_path], area)
          else
            attributes[:url] = '#'
          end
          item = create_documentation_item_with_context(area, attributes)
          entry[:children].each_with_index do |child, index|
            create_documentation_navigation_item(area, child, index, parent: item)
          end
        else
          attributes[:item_type] = 'link'
          attributes[:linkable] = documentation_page_for(entry[:title], entry[:path], area)
          create_documentation_item_with_context(area, attributes)
        end
      end

      def documentation_title(name)
        base = name.to_s.sub(/\.md\z/i, '')
        return 'Overview' if base.casecmp('readme').zero?

        base.tr('_-', ' ').squeeze(' ').strip.titleize
      end

      def documentation_relative_path(path)
        path.relative_path_from(documentation_root).to_s
      end

      def documentation_url(relative_path)
        File.join(documentation_url_prefix, relative_path)
      end

      def create_documentation_item_with_context(area, attributes)
        puts "Creating documentation navigation item #{attributes.inspect}" if ENV['DEBUG_DOCUMENTATION_NAV'] == '1'
        area.navigation_items.create!(attributes)
      rescue ActiveRecord::RecordInvalid => e
        raise ActiveRecord::RecordInvalid.new(e.record), "#{e.message} -- #{attributes.inspect}"
      end

      def documentation_page_for(title, relative_path, sidebar_nav_area = nil) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        slug = documentation_slug(relative_path)
        attrs = documentation_page_attributes(title, slug, relative_path, sidebar_nav_area)
        page = ::BetterTogether::Page.i18n.find_by(slug: slug)

        if page
          locked_page = ::BetterTogether::Page.lock.find(page.id)
          locked_page.page_blocks.destroy_all
          locked_page.reload
          locked_page.assign_attributes(attrs)
          locked_page.save!
          # Re-set the slug after save in case FriendlyId regenerated it
          locked_page.update_columns(slug: slug) if locked_page.slug != slug
          locked_page
        else
          new_page = ::BetterTogether::Page.create!(attrs)
          # Re-set the slug after creation in case FriendlyId regenerated it
          new_page.slug = slug if new_page.slug != slug
          new_page.save!(validate: false) if new_page.changed?
          new_page
        end
      end

      def documentation_page_attributes(title, slug, relative_path, sidebar_nav_area = nil) # rubocop:todo Metrics/MethodLength
        attrs = {
          title_en: title,
          slug_en: slug, # Set slug directly via Mobility to bypass FriendlyId normalization
          published_at: Time.zone.now,
          privacy: 'public',
          protected: true,
          layout: 'layouts/better_together/full_width_page',
          page_blocks_attributes: [
            {
              block_attributes: {
                type: 'BetterTogether::Content::Markdown',
                markdown_file_path: documentation_file_path(relative_path)
              }
            }
          ]
        }

        # Associate the documentation navigation area as the sidebar nav
        attrs[:sidebar_nav] = sidebar_nav_area if sidebar_nav_area.present?

        attrs
      end

      def documentation_slug(path)
        relative = path.is_a?(Pathname) ? documentation_relative_path(path) : path.to_s
        # Remove .md extension, downcase, and preserve directory structure with slashes
        base_slug = relative.sub(/\.md\z/i, '').downcase.tr('_', '-')
        base_slug = 'overview' if base_slug.blank?
        "docs/#{base_slug}"
      end

      def documentation_file_path(relative_path)
        documentation_root.join(relative_path).to_s
      end

      def default_documentation_file(path)
        %w[README.md readme.md index.md INDEX.md].each do |filename|
          file_path = path.join(filename)
          return documentation_relative_path(file_path) if file_path.exist?
        end
        nil
      end

      def documentation_root
        BetterTogether::Engine.root.join('docs')
      end

      def documentation_url_prefix
        '/docs'
      end
    end
  end
end
