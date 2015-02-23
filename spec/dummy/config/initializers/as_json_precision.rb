# Increase precision of date_time conversion with as_json
# to match our db precision
ActiveSupport::JSON::Encoding.time_precision = 6
