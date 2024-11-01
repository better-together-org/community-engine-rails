
namespace :better_together do
  namespace :migrate_data do
    desc 'Migrate existing page contents to blocks'
    task page_contents_to_blocks: :environment do
      content_translations = ActionText::RichText.where(
        record_type: 'BetterTogether::Page',
        name: 'content',
        locale: I18n.available_locales
      )

      pages = BetterTogether::Page.where(id: content_translations.pluck(:record_id))

      puts pages.size, 'pages'
      content_attrs = BetterTogether::Page.localized_attribute_list.select do |attribute|
        attribute.to_s.start_with?('content')
      end

      Mobility.with_locale(:en) do
        pages.each do |page|
          next if page.page_blocks.any?

          page_block = page.page_blocks.build
          block = page_block.build_block(type: 'BetterTogether::Content::RichText', creator_id: BetterTogether::Person.first&.id)

          content_attrs.each do |attr|
            block.public_send("#{attr}=", page.public_send(attr))
          end

          page_block.save!
        end
      end
    end

    desc 'migrates html content to html translatable text field'
    task html_block_translatable_html: :environment do
      Mobility.with_locale(:en) do
        BetterTogether::Content::Html.all.each do |html|
          html.content = html.html_content

          html.save
        end
      end
    end

    desc 'Migrate nested set structure for navigation items'
    task nested_set_for_navigation_items: :environment do
      BetterTogether::NavigationItem.locking_column = nil

      # Reset column information to ensure the schema is updated for new columns
      BetterTogether::NavigationItem.reset_column_information

      # Rebuild the nested set structure to ensure correct lft and rgt values
      BetterTogether::NavigationItem.rebuild!

      # Initialize the setting process by iterating over all root nodes ordered by position
      BetterTogether::NavigationItem.top_level.positioned.find_each do |root_node|
        set_nested_set_positions(root_node)
      end

      # Rebuild the nested set structure to ensure correct lft and rgt values
      BetterTogether::NavigationItem.rebuild!

      # Restore the locking column
      BetterTogether::NavigationItem.locking_column = :lock_version
      puts "Nested set migration completed successfully."
    end

    # Recursive method to move nodes within the nested set hierarchy
    def set_nested_set_positions(node, parent = nil)
      # If there is a parent, make this node a child of the parent
      if parent
        node.move_to_child_of(parent)
      else
        node.move_to_root
      end

      # Fetch and process all child nodes of the current node, ordered by position
      children = BetterTogether::NavigationItem.where(parent_id: node.id).order(:position)

      children.each do |child|
        # Recursively set positions for child nodes, with `node` as their parent
        set_nested_set_positions(child, node)
      end
    end
  end
end
