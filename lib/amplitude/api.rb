# frozen_string_literal: true
require 'json'
require 'net/https'
require 'uri'
require 'amplitude/event'

module Amplitude
  class API
    TRACK_URI_STRING        = 'https://api.amplitude.com/httpapi'.freeze
    IDENTIFY_URI_STRING     = 'https://api.amplitude.com/identify'.freeze
    SEGMENTATION_URI_STRING = 'https://amplitude.com/api/2/events/segmentation'.freeze
    DELETION_URI_STRING     = 'https://amplitude.com/api/2/deletions/users'.freeze

    USER_WITH_NO_ACCOUNT = "user who doesn't have an account".freeze

    class << self
      # ==== Event Tracking related methods

      # Send a single event immediately to the AmplitudeAPI
      #
      # @param [String] event_name a string that describes the event, e.g. "clicked on Home"
      # @param [String] user a string or integer that uniquely identifies a user.
      # @param [String] device a string that uniquely identifies the device.
      # @param [Hash] options a hash that contains event_properties ()a hash that is serialized to JSON,
      # and can contain any other property to be stored on the Event) and user_properties a hash that is
      # serialized to JSON, and contains user properties to be associated with the user
      #
      # @return [Net::HTTPResponse]
      def send_event(event_name, user, device, options = {})
        event = Amplitude::Event.new(
          user_id: user,
          device_id: device,
          event_type: event_name,
          event_properties: options.fetch(:event_properties, {}),
          user_properties: options.fetch(:user_properties, {})
        )
        track(event)
      end

      # Converts a series of AmplitudeAPI::Event objects into a body
      # suitable for the Amplitude API
      #
      # @param [Array<AmplitudeAPI::Event>] events an array of events in a single request to Amplitude
      #
      # @return [Hash]
      def track_body(*events)
        event_body = events.flatten.map(&:to_hash)

        {
          api_key: Amplitude.configuration.api_key,
          event: JSON.generate(event_body)
        }
      end

      # Send one or more Events to the Amplitude API
      #
      # @param [Array<AmplitudeAPI::Event>] events an array of events in a single request to Amplitude
      #
      # @return [Net::HTTPResponse]
      def track(*events)
        uri = URI(TRACK_URI_STRING)
        Net::HTTP.post_form(uri, track_body(events))
      end

      # ==== Identification related methods

      # Send a single event immediately to the AmplitudeAPI
      #
      # @param [String] user_id a string or integer that uniquely identifies a user.
      # @param [String] device_id a string that uniquely identifies the device.
      # @param [Hash] user_properties a hash that is serialized to JSON,
      # and contains user properties to be associated with the user
      #
      # @return [Net::HTTPResponse]
      def send_identify(user_id, device_id, user_properties = {})
        identification = Amplitude::API::Identification.new(
          user_id: user_id,
          device_id: device_id,
          user_properties: user_properties
        )
        identify(identification)
      end

      # Converts a series of AmplitudeAPI::Identification objects into a body
      # suitable for the Amplitude API
      #
      # @param [Array<AmplitudeAPI::Identification>] identifications an array of identifications in a single request to Amplitude
      #
      # @return [Hash]
      def identify_body(*identifications)
        identification_body = identifications.flatten.map(&:to_hash)

        {
          api_key: Amplitude.configuration.api_key,
          identification: JSON.generate(identification_body)
        }
      end

      # Send one or more Identifications to the Amplitude Identify API
      #
      # @param [Array<AmplitudeAPI::Identification>] identifications an array of identifications in a single request to Amplitude
      #
      # @return [Net::HTTPResponse]
      def identify(*identifications)
        uri = URI(TRACK_URI_STRING)
        Net::HTTP.post_form(uri, identify_body(identifications))
      end

      # ==== Event Segmentation related methods

      # Get metrics for an event with segmentation.
      #
      # @param [Hash] event_hash a hash that defines event.
      # @param [Time] start_time a start time.
      # @param [Time] end_time a end time.
      # @param [Array] options an array that contains:
      #   [String] m a string that defines aggregate function.
      #     For non-property metrics: "uniques", "totals", "pct_dau", or "average" (default: "uniques").
      #     For property metrics: "histogram", "sums", or "value_avg"
      #     (note: a valid "group_by" value is required in parameter e).
      #   [Integer] i an integer that defines segmentation interval.
      #     Set to -300000, -3600000, 1, 7, or 30 for realtime, hourly, daily, weekly,
      #     and monthly counts, respectively (default: 1). Realtime segmentation is capped at 2 days,
      #     hourly segmentation is capped at 7 days, and daily at 365 days.
      #   [Array] s an array that defines segment definitions.
      #   [String] g a string that defines property to group by.
      #   [Integer] limit an integer that defines number of Group By values
      #     returned (default: 100). The maximum limit is 1000.
      #
      # @return [Net::HTTPResponse]
      def segmentation(event_hash, start_time, end_time, **options)
        uri = URI(SEGMENTATION_URI_STRING)
        params = {
          e:     event_hash.to_json,
          m:     options[:m],
          start: start_time.strftime('%Y%m%d'),
          end:   end_time.strftime('%Y%m%d'),
          i:     options[:i],
          s:     (options[:s] || []).map(&:to_json),
          g:     options[:g],
          limit: options[:limit]
        }.delete_if { |_, value| value.nil? }
        uri.query = URI.encode_www_form(params)
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(Amplitude.configuration.api_key, Amplitude.configuration.secret_key)
        http.request(request)
      end

      # ==== GDPR compliance methods

      # Delete a user from amplitude when they request it to comply with GDPR
      # You must pass in either an array of user_ids or an array of amplitude_ids
      #
      # @param [Array] (optional) user_ids the user ids to delete based on your database
      # @param [Array] (optional) amplitude_ids the amplitude ids to delete based on the amplitude database
      # @param [String] (optional) requester the email address of the person who is requesting the deletion, optional but useful for reporting
      #
      # @return [Net::HTTPResponse]
      def delete(user_ids: nil, amplitude_ids: nil, requester: nil)
        uri = URI(DELETION_URI_STRING)
        params = {
          amplitude_ids: amplitude_ids,
          user_ids: user_ids,
          requester: requester
        }.delete_if { |_, value| value.nil? }
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.body = URI.encode_www_form(params)
        request.basic_auth(Amplitude.configuration.api_key, Amplitude.configuration.secret_key)
        http.request(request)
      end
    end
  end
end
