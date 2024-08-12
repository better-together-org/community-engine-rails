# frozen_string_literal: true

# app/controllers/better_together/navigation_items_controller.rb

module BetterTogether
  # Responds to requests for navigation items
  class NavigationItemsController < FriendlyResourceController
    before_action :set_pages, only: %i[new edit create update]
    before_action :set_navigation_area
    before_action :set_navigation_item, only: %i[show edit update destroy]

    def index
      authorize resource_class
      @navigation_items =
        policy_scope(resource_collection)
    end

    def show
      authorize @navigation_item
    end

    def new
      @navigation_item = new_navigation_item
      authorize @navigation_item
    end

    def edit
      authorize @navigation_item
    end

    def create
      @navigation_item = new_navigation_item
      @navigation_item.assign_attributes(navigation_item_params)
      authorize @navigation_item

      if @navigation_item.save
        redirect_to @navigation_area, only_path: true, notice: 'Navigation item was successfully created.'
      else
        render :new
      end
    end

    def update
      authorize @navigation_item

      if @navigation_item.update(navigation_item_params)
        redirect_to @navigation_area, only_path: true, notice: 'Navigation item was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      authorize @navigation_item
      @navigation_item.destroy
      redirect_to navigation_area_navigation_items_url(@navigation_area),
                  notice: 'Navigation item was successfully destroyed.'
    end

    private

    def parent_id_param
      params[:parent_id]
    end

    def new_navigation_item
      @navigation_area.navigation_items.new do |item|
        item.parent_id = parent_id_param if parent_id_param.present?
      end
    end

    def set_pages
      @pages = ::BetterTogether::Page.all
    end

    def set_navigation_area
      @navigation_area ||= find_by_translatable(
        translatable_type: ::BetterTogether::NavigationArea.name,
        friendly_id: params[:navigation_area_id]
      )
      authorize @navigation_area
    end

    def set_navigation_item
      @navigation_item = set_resource_instance
      # Removed the authorize call from here as it's now in each action
    end

    def navigation_item_params
      params.require(:navigation_item).permit(:navigation_area_id, :title, :url, :icon, :position, :visible,
                                              :item_type, :linkable_id, :linkable_type, :parent_id)
    end

    def resource_class
      ::BetterTogether::NavigationItem
    end

    def resource_collection
      resource_class.with_translations
                    .top_level
                    .includes(children: [:string_translations])
                    .where(navigation_area: @navigation_area)
    end
  end
end
