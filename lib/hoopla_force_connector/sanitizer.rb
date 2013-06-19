class HooplaForceConnector
  # Handles sanitization of values that come out of the salesforce WebServices API.
  # Basically there's some oddities like extra wrappers on a return value or ids
  # coming through as arrays. See the test for examples of what this handles.
  class Sanitizer
    def self.sanitize(raw)
      new(raw).sanitize
    end

    def initialize(raw)
      @raw = raw
      raise "Don't know how to handle more than one key: #{@raw.inspect}" unless @raw.keys.size == 1
      @result = @raw.values.first[:result]
    end

    def sanitize
      send("sanitize_#{@raw.keys.first.to_s}")
    end

    # These come in from Salesforce messages
    def sanitize_notifications
      notifications = [@raw[:notifications][:notification]].flatten
      notifications.map { |n| n[:s_object].without_keys(:sf) }
    end

    def sanitize_query_response
      records = @result[:records]
      records = [records].flatten.compact
      dedup_ids(remove_type(records))
    end
    alias_method :sanitize_query_more_response, :sanitize_query_response

    def sanitize_retrieve_response
      records = @result
      records = [records].flatten.compact
      dedup_ids(remove_type(records))
    end

    def sanitize_get_updated_response
      @result[:ids] = [@result[:ids]].flatten.compact
      @result
    end

    def remove_type(records)
      records.map { |r| r.without_keys(:type) }
    end

    def dedup_ids(records)
      records.map do |r|
        case r[:id]
        when nil
          r.without_keys(:id)
        when Array
          r[:id] = r[:id].first
          r
        else
          r
        end
      end
    end

    def method_missing(meth, *args, &block)
      if meth.to_s =~ /^sanitize_/
        @result
      else
        super
      end
    end

    def respond_to?(meth)
      super || meth.to_s =~ /^sanitize_/
    end
  end
end
