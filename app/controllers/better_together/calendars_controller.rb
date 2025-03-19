module BetterTogether
  class CalendarsController < FriendlyResourceController
    before_action :set_better_together_calendar, only: %i[ show edit update destroy ]
  
    # GET /better_together/calendars
    def index
      @calendars = BetterTogether::Calendar.all
    end
  
    # GET /better_together/calendars/1
    def show
    end
  
    # GET /better_together/calendars/new
    def new
      @calendar = resource_instance
    end
  
    # GET /better_together/calendars/1/edit
    def edit
    end
  
    # POST /better_together/calendars
    # def create
    #   @calendar = BetterTogether::Calendar.new(better_together_calendar_params)
  
    #   if @calendar.save
    #     redirect_to @calendar, notice: "Calendar was successfully created."
    #   else
    #     render :new, status: :unprocessable_entity
    #   end
    # end
  
    # PATCH/PUT /better_together/calendars/1
    def update
      if @calendar.update(better_together_calendar_params)
        redirect_to @calendar, notice: "Calendar was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end
  
    # DELETE /better_together/calendars/1
    def destroy
      @calendar.destroy!
      redirect_to better_together_calendars_url, notice: "Calendar was successfully destroyed.", status: :see_other
    end
  
    private
      # Use callbacks to share common setup or constraints between actions.
      def set_better_together_calendar
        @calendar = resource_instance
      end

      def resource_class
        BetterTogether::Calendar
      end

      # Only allow a list of trusted parameters through.
      def better_together_calendar_params
        params.require(:better_together_calendar).permit(:identifier, :name, :description, :slug, :privacy, :protected)
      end
  end
end