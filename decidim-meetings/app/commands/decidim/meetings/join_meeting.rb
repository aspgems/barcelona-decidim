# frozen_string_literal: true

module Decidim
  module Meetings
    # This command is executed when the user joins a meeting.
    class JoinMeeting < Rectify::Command
      # Initializes a JoinMeeting Command.
      #
      # meeting - The current instance of the meeting to be joined.
      # user - The user joining the meeting.
      def initialize(meeting, user)
        @meeting = meeting
        @user = user
      end

      # Creates a meeting registration if the meeting has registrations enabled
      # and there are available slots.
      #
      # Broadcasts :ok if successful, :invalid otherwise.
      def call
        @meeting.with_lock do
          return broadcast(:invalid) unless can_join_meeting?
          create_registration
          send_notification
        end
        broadcast(:ok)
      end

      private

      def create_registration
        Decidim::Meetings::Registration.create!(meeting: @meeting, user: @user)
      end

      def can_join_meeting?
        @meeting.registrations_enabled? && @meeting.has_available_slots?
      end

      def participatory_space_admins
        @meeting.feature.participatory_space.admins
      end

      def send_notification
        if occupied_slots_over?(0.5)
          Decidim::EventsManager.publish(
            event: "decidim.events.meetings.meeting_registrations_over_fifty",
            event_class: Decidim::Meetings::MeetingRegistrationsOverFifty,
            resource: @meeting,
            recipient_ids: participatory_space_admins.pluck(:id),
            user: @user
          )
        end
      end

      def occupied_slots_over?(percentage)
        @meeting.remaining_slots == (@meeting.available_slots * (1 - percentage)).floor
      end
    end
  end
end
