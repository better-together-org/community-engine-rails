# frozen_string_literal: true

module BetterTogether
  # Responds to requests for navigation areas
  class NavigationAreasController < FriendlyResourceController
    before_action :set_navigation_area, only: %i[show edit update destroy]

    def index
      authorize resource_class
      @navigation_areas = policy_scope(resource_class.with_translations)
    end

    def show # rubocop:todo Metrics/MethodLength
      authorize @navigation_area

      @navigation_items = @navigation_area.navigation_items.top_level.positioned
                                          .includes(
                                            :navigation_area,
                                            :string_translations,
                                            linkable: [:string_translations],
                                            children: [
                                              :navigation_area,
                                              :string_translations,
                                              { linkable: [:string_translations],
                                                children: [
                                                  :navigation_area,
                                                  :string_translations,
                                                  { linkable: [:string_translations],
                                                    children: [
                                                      :navigation_area,
                                                      :string_translations,
                                                      { linkable: [:string_translations] }
                                                    ] }
                                                ] }
                                            ]
                                          )
    end

    def new
      @navigation_area = resource_class.new
      authorize @navigation_area
    end

    def edit
      authorize @navigation_area
    end

    def create
      @navigation_area = resource_class.new(navigation_area_params)
      authorize @navigation_area

        if @navigation_area.save
          redirect_to [:host, @navigation_area], only_path: true, notice: 'Navigation area was successfully created.'
      else
        render :new
      end
    end

    def update
      authorize @navigation_area

        if @navigation_area.update(navigation_area_params)
          redirect_to [:host, @navigation_area], only_path: true, notice: 'Navigation area was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      authorize @navigation_area
      @navigation_area.destroy
        redirect_to host_navigation_areas_url, notice: 'Navigation area was successfully destroyed.'
    end

    private

    def set_navigation_area
      @navigation_area = set_resource_instance
      # The call to `authorize` is removed from here and placed in each action
    end

    def navigation_area_params
      params.require(:navigation_area).permit(:name, :slug, :visible, :style, :protected)
    end

    def resource_class
      ::BetterTogether::NavigationArea
    end
  end
end
