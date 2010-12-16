module SalesforceResponses
  RECORDS_TO_RETRIEVE = 2

  def self.method_missing(meth, *args, &block)
    filename = File.dirname(__FILE__) + "/salesforce_responses/#{meth}.yml"
    if File.exists?(filename)
      YAML.load_file(filename)
    else
      super
    end
  end

  def self.slice!(coll)
    if coll.is_a?(Array)
      coll.slice!(RECORDS_TO_RETRIEVE..-1)
    end
  end

  def self.generate_query_response(type)
    raise "This is broken. Try switching it to just limit the query results in SOQL to avoid queryMore appending
           to an unsanitized string."
    sf = Salesforce.default_client
    sf.should_sanitize = false
    resp = sf.query(type.soql_table)
    slice!(resp[:query_response][:result][:records])
    write_to_responses("query_#{type.table_name}", resp)
  end
 
  def self.generate_updated_response(type)
    sf = Salesforce.default_client
    sf.should_sanitize = false

    resp = sf.get_updated(:s_object_type => type.to_s,
                          :start_date => 29.days.ago,
                          :end_date => Time.now.utc)
    slice!(resp[:get_updated_response][:result][:ids])
    write_to_responses("get_updated_#{type.table_name}", resp)
  end

  def self.write_to_responses(name, data)
    File.open(Rails.root.join("test", "support", "salesforce_responses", "#{name}.yml"), "w") do |f|
      f.print data.to_yaml
    end
  end
end
