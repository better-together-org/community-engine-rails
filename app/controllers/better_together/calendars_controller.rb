# frozen_string_literal: true

module BetterTogether
  # CRUD for calendars
  class CalendarsController < FriendlyResourceController
    # GET /better_together/calendars
    def show
      @calendar = set_resource_instance
      authorize @calendar
      @upcoming_events = @calendar.events.upcoming.order(:starts_at)
      @past_events = @calendar.events.past.order(starts_at: :desc)
    end

    # GET /better_together/calendars/:id/feed.ics
    # Returns ICS feed for calendar subscription
    # Supports token-based authentication for external calendar apps
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def feed
      @calendar = set_resource_instance

      # Token-based authentication takes precedence over user authentication
      if params[:token].present?
        # Skip Pundit authorization for token-based access
        skip_authorization

        unless valid_subscription_token?
          head :unauthorized
          return
        end
      else
        # For calendars without token, require authentication and authorization
        unless user_signed_in?
          skip_authorization # Skip authorization before returning unauthorized
          head :unauthorized
          return
        end
        authorize @calendar
      end

      events = @calendar.events.order(:starts_at)

      respond_to do |format|
        format.ics do
          ics_content = BetterTogether::Ics::Generator.new(events).generate
          send_data ics_content,
                    type: 'text/calendar; charset=utf-8',
                    disposition: "inline; filename=\"#{@calendar.slug}.ics\""
        end

        format.json do
          json_content = BetterTogether::CalendarExport::GoogleCalendarJson.new(events).generate
          send_data json_content,
                    type: 'application/json; charset=utf-8',
                    disposition: "inline; filename=\"#{@calendar.slug}.json\""
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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

    def valid_subscription_token?
      return false unless @calendar&.subscription_token.present?

      ActiveSupport::SecurityUtils.secure_compare(
        @calendar.subscription_token,
        params[:token].to_s
      )
    end

    def permitted_attributes
      resource_class.extra_permitted_attributes + %i[community_id]
    end

    def resource_class
      BetterTogether::Calendar
    end
  end
end
