# frozen_string_literal: true

module Amplitude
  class Event
    ATTRIBUTES = %i(
      user_id device_id event_type time event_properties user_properties groups app_version platform os_name
      os_version device_brand device_manufacturer device_model carrier country region city dma language price
      quantity revenue product_id revenue_type location_lat location_lng ip insert_id).freeze

    OPTIONAL_ATTRIBUTES = %i(
      device_id time app_version platform os_name os_version device_model country region city ip location_lat
      location_lng insert_id).freeze

    ATTRIBUTES.each { |attribute| attr_accessor ":#{attribute}".to_sym }

    # Create a new Event
    #
    # See (Amplitude HTTP API Documentation)[https://amplitude.zendesk.com/hc/en-us/articles/204771828-HTTP-API]
    # for a list of valid parameters and their types.
    def initialize(attributes = {})
      attributes.each do |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
      end
      validate_arguments
    end

    def user_id=(value)
      @user_id =
        if value.respond_to?(:id)
          value.id
        else
          value || Amplitude::API::USER_WITH_NO_ACCOUNT
        end
    end

    # @return [ Hash ] A serialized Event
    #
    # Used for serialization and comparison
    def to_hash
      {
        event_type: event_type,
        event_properties: formatted_event_properties,
        user_properties: formatted_user_properties,
        user_id: user_id,
        device_id: device_id
      }.merge(optional_properties).merge(revenue_hash).delete_if { |_, value| value.nil? }
    end

    alias to_h to_hash

    # @return [ true, false ]
    #
    # Compares +to_hash+ for equality
    def ==(other)
      return false unless other.respond_to?(:to_h)
      to_h == other.to_h
    end

    private

    def formatted_time
      Amplitude.configuration.time_formatter.call(time)
    end

    def formatted_event_properties
      Amplitude.configuration.event_properties_formatter.call(event_properties)
    end

    def formatted_user_properties
      Amplitude.configuration.user_properties_formatter.call(user_properties)
    end

    def validate_arguments
      validate_required_arguments
      validate_revenue_arguments
    end

    def validate_required_arguments
      raise ArgumentError, 'You must provide user_id or device_id (or both)' unless user_id || device_id
      raise ArgumentError, 'You must provide event_type' unless event_type
      raise ArgumentError, 'Invalid event_type - cannot match a reserved event name' if reserved_event?(event_type)
    end

    def validate_revenue_arguments
      return self.quantity ||= 1 if price
      raise ArgumentError, 'You must provide a price in order to use the product_id' if product_id
      raise ArgumentError, 'You must provide a price in order to use the revenue_type' if revenue_type
    end

    # @return [ Hash ] Optional properties
    def optional_properties
      self.class.OPTIONAL_ATTRIBUTES.map do |prop|
        val = prop == :time ? formatted_time : send(prop)
        val ? [prop, val] : nil
      end.delete_if { |_, value| value.nil? }.to_h
    end

    def revenue_hash
      {
        price: price,
        quantity: quantity,
        revenue: revenue,
        product_id: product_id,
        revenue_type: revenue_type
      }.delete_if { |_, value| value.nil? }
    end

    # @return [ true, false ]
    #
    # Returns true if the event type matches one reserved by Amplitude API.
    def reserved_event?(type)
      [
        '[Amplitude] Start Session',
        '[Amplitude] End Session',
        '[Amplitude] Revenue',
        '[Amplitude] Revenue (Verified)',
        '[Amplitude] Revenue (Unverified)',
        '[Amplitude] Merged User'
      ].include?(type)
    end
  end
end
