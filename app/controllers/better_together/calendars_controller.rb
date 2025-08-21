# frozen_string_literal: true

module BetterTogether
  # CRUD for calendars
  class CalendarsController < FriendlyResourceController
    # GET /better_together/calendars

    # GET /better_together/calendars/new
    def new
      @calendar = resource_instance
    end

    # GET /better_together/calendars/1/edit
    def edit; end

    # POST /better_together/calendars
    # def create
    #   @calendar = BetterTogether::Calendar.new(better_together_calendar_params)

    #   if @calendar.save
    #     redirect_to @calendar, notice: "Calendar was successfully created."
    #   else
    #     render :new, status: :unprocessable_content
    #   end
    # end

    # PATCH/PUT /better_together/calendars/1
    # def update
    #   if @calendar.update(better_together_calendar_params)
    #     redirect_to @calendar, notice: "Calendar was successfully updated.", status: :see_other
    #   else
    #     render :edit, status: :unprocessable_content
    #   end
    # end

    # DELETE /better_together/calendars/1
    def destroy
      @calendar.destroy!
      redirect_to better_together_calendars_url,
                  notice: t('flash.generic.destroyed', resource: t('resources.calendar')),
                  status: :see_other
    end

    private

    def permitted_attributes
      resource_class.extra_permitted_attributes + %i[community_id]
    end

    def resource_class
      BetterTogether::Calendar
    end
  end
end
