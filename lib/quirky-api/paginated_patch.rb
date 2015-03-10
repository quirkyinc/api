module Paginated
#
# There are 2 types of pagination:
#
# 1. Cursor Pagination:
#    We ask for the next batch after a cursor.
#    - Specify {use_cursor: true}.
#    - Do not specify page.
#    - The response will include paginated_meta with has_next_page [Boolean]
#
# 2. Page Pagination:
#    We ask for a specific page.
#    - Specify the page you want {page: 3}.
#    - Do not specify use_cursor or set it to false.
#    - The response will include paginated_meta with total_page [Integer] and has_next_page [Boolean]
#
# Example:
#
#  paginated_options: {
#    useCursor: true,                                   (optional) [Boolean] = If we want to paginate with cursor. If false or not specified - will do page pagination.
#    page: 2,                                           (optional) [Integer] = The page we want to fetch in page pagination. If not specified will be set to 1. Not used in cursor pagination.
#    perPage: 15,                                       (optional) [Integer] = The number of items per page. If not specified will default to 20.
#    order: 'desc',                                     (optional) [String]  = The order. 'asc' or 'desc'. If not specified will default to 'asc'.
#    orderColumn: 'created_at',                         (optional) [String]  = The name of the column to order by. If not specified will default to 'id'.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       //     'id': '524'
#                                                                              NOTE!! - only number or datetime columns are accepted.
#    values_in: {                                       (optional) [Hash]    = Values for SQL 'IN'.
#      'status': 'accepted',                                                   Each key is a column_name. Each value is an array of values or individual value.
#      'state': ['public', 'in_review_queue']                                  Only number or datetime columns are accepted.
#    },
#    values_not_in: {                                   (optional) [Hash]    = Values for SQL 'NOT IN'.
#      'status': 'accepted',                                                   Each key is a column_name. Each value is  an array of values or individual value.
#      'state': ['public', 'in_review_queue']                                  Only number or datetime columns are accepted.
#    },
#    greater_than: {                                    (optional) [Hash]    = Value for SQL '>'.
#      'rating': 4,                                                            Each key is a column_name.
#      'created_at': '2015-02-10T12:40:36.018645-05:00'                        Only number or datetime columns are accepted.
#    },
#    greater_than_or_equal_to: {                        (optional) [Hash]    = Value for SQL '>='.
#      'rating': 4,                                                            Each key is a column_name.
#      'created_at': '2015-02-10T12:40:36.018645-05:00'                        Only number or datetime columns are accepted.
#    },
#    less_than: {                                       (optional) [Hash]    = Value for SQL '<'.
#      'rating': 4,                                                            Each key is a column_name.
#      'created_at': '2015-02-10T12:40:36.018645-05:00'                        Only number or datetime columns are accepted.
#    },
#    less_than_or_equal_to: {                           (optional) [Hash]    = Value for SQL '<='.
#      'rating': 4,                                                            Each key is a column_name.
#      'created_at': '2015-02-10T12:40:36.018645-05:00'                        Only number or datetime columns are accepted.
#    },
#  }

  # Error class for the module
  class InvalidPaginationOptions < StandardError
  end

  # Extend ActiveRecord::Relation with pagination
  class ActiveRecord::Relation

    def paginated(paginated_options={})
      paginated_options = {} if paginated_options.nil?

      # Convert all non-string values to the right format
      case paginated_options[:use_cursor]
        when 'true', true
          paginated_options[:use_cursor] = true
        when 'false', false
          paginated_options[:use_cursor] = false
        else
          raise Paginated::InvalidPaginationOptions, 'use_cursor can only be true of false' if paginated_options[:use_cursor].present?
      end
      paginated_options[:page] = paginated_options[:page].to_i if paginated_options[:page].present?
      paginated_options[:per_page] = paginated_options[:per_page].to_i if paginated_options[:per_page].present?

      raise Paginated::InvalidPaginationOptions, 'can not do both cursor pagination and page pagination' if paginated_options[:use_cursor].present? && paginated_options[:page].present?

      # If we are not doing cursor pagination, we must have page. If we don't have it - we assume 1
      paginated_options[:page] = paginated_options[:page] || 1 unless paginated_options[:use_cursor]

      raise Paginated::InvalidPaginationOptions, 'page must be 1 or bigger' if paginated_options[:page].present? && paginated_options[:page] < 1
      raise Paginated::InvalidPaginationOptions, "order can only be 'asc', 'ASC', 'desc', 'DESC' (or nil which will default to 'ASC')" if paginated_options[:order].present? && !%w(asc ASC desc DESC).include?(paginated_options[:order])

      # The base class we will use for the sql statements
      sql_base_class = self.base_class.table_name

      # Keep track of the attributes the model has that we can run sql on
      model_attributes = []

      # All the schema attributes
      model_attributes += self.base_class.column_names

      # If we have psql hstores or json stores add those too
      model_attributes += self.base_class.stored_attributes.values

      model_attributes.flatten!

      # If we have order_column - raise error if order_column is for a column that doesn't exist
      if paginated_options[:order_column].present?
        raise Paginated::InvalidPaginationOptions, "can not sort by '#{paginated_options[:order_column]}' as such attribute or store accessor does not exist" unless model_attributes.include?(paginated_options[:order_column].to_s)

        # Raise error if :order_column is not float, integer or date_time column, as we can not sort by it
        # Excluding psql store columns, as their type is determined by the validations, and we can not automatically infer it
        unless self.base_class.stored_attributes.values.include?(paginated_options[:order_column])
          allowed_types = [:integer, :float, :datetime]
          requested_column_type = self.base_class.columns_hash[paginated_options[:order_column].to_s].type
          unless allowed_types.include?(requested_column_type)
            raise Paginated::InvalidPaginationOptions, "can not order by column of type '#{requested_column_type}'"
          end
        end
      end

      # Set defaults if not sent
      paginated_options[:order_column] = 'id' unless paginated_options[:order_column].present?
      paginated_options[:order] = 'ASC' unless paginated_options[:order].present?
      paginated_options[:per_page] = 20 if paginated_options[:per_page].blank?

      # Upper case the order
      paginated_options[:order] = paginated_options[:order].upcase

      # Setup where
      conditions = []
      condition_params = []

      # If we are doing cursor-pagination
      if paginated_options[:use_cursor]
        offset = 0

        # If we didn't send cursor - we want the first page
        # Otherwise we want it above or below the cursor (depending on the order)
        if paginated_options[:cursor].present?
          direction = paginated_options[:order] == 'ASC' ? '>' : '<'
          conditions << "#{sql_base_class}.#{paginated_options[:order_column]} #{direction} ?"

          # If the column type is datetime, we need to convert the to datetime
          cursor = paginated_options[:cursor]
          requested_column_type = self.base_class.columns_hash[paginated_options[:order_column].to_s].type
          cursor = cursor.to_datetime if requested_column_type == :datetime

          condition_params << cursor
        end

      # If we are doing page-pagination
      else
        offset = (paginated_options[:page] - 1) * paginated_options[:per_page]
      end

      # Filter by values_in
      if paginated_options[:values_in].present?
        raise Paginated::InvalidPaginationOptions, "'values_in' must be a hash" unless paginated_options[:values_in].is_a?(Hash)

        paginated_options[:values_in].each do |column_name, values|
          # Verify the column exists on the model
          raise Paginated::InvalidPaginationOptions, "'#{column_name}' is not a valid column name for 'values_in'" unless model_attributes.include?(column_name.to_s)

          conditions << "#{sql_base_class}.#{column_name} IN (?)"

          # If we have a single value, convert it to array
          values_in = values.is_a?(Array) ? values : [values]

          # If the column type is datetime, we need to convert the values to ruby datetime values
          column_type = self.base_class.columns_hash[column_name.to_s].type
          values_in.collect!{|value| value.to_datetime} if column_type == :datetime

          condition_params << values_in
        end
      end

      # Filter by values_not_in
      if paginated_options[:values_not_in].present?
        raise Paginated::InvalidPaginationOptions, "'values_not_in' must be a hash" unless paginated_options[:values_not_in].is_a?(Hash)

        paginated_options[:values_not_in].each do |column_name, values|
          # Verify the column exists on the model
          raise Paginated::InvalidPaginationOptions, "'#{column_name}' is not a valid column name for 'values_not_in'" unless model_attributes.include?(column_name.to_s)

          conditions << "#{sql_base_class}.#{column_name} NOT IN (?)"

          # If we have a single value, convert it to array
          values_in = values.is_a?(Array) ? values : [values]

          # If the column type is datetime, we need to convert the values to ruby datetime values
          column_type = self.base_class.columns_hash[column_name.to_s].type
          values_in.collect!{|value| value.to_datetime} if column_type == :datetime

          condition_params << values_in
        end
      end

      # Filter by greater_than
      if paginated_options[:greater_than].present?
        added_conditions, added_condition_params = greater_smaller_conditions(paginated_options[:greater_than], 'greater_than', sql_base_class, model_attributes)
        conditions += added_conditions
        condition_params += added_condition_params
      end

      # Filter by greater_than_or_equal_to
      if paginated_options[:greater_than_or_equal_to].present?
        added_conditions, added_condition_params = greater_smaller_conditions(paginated_options[:greater_than_or_equal_to], 'greater_than_or_equal_to', sql_base_class, model_attributes)
        conditions += added_conditions
        condition_params += added_condition_params
      end

      # Filter by smaller_than
      if paginated_options[:smaller_than].present?
        added_conditions, added_condition_params = greater_smaller_conditions(paginated_options[:smaller_than], 'smaller_than', sql_base_class, model_attributes)
        conditions += added_conditions
        condition_params += added_condition_params
      end

      # Filter by smaller_than_or_equal_to
      if paginated_options[:smaller_than_or_equal_to].present?
        added_conditions, added_condition_params = greater_smaller_conditions(paginated_options[:smaller_than_or_equal_to], 'smaller_than_or_equal_to', sql_base_class, model_attributes)
        conditions += added_conditions
        condition_params += added_condition_params
      end

      # Join the conditions and get the correctly scoped objects
      conditions_compiled = [conditions.join(' AND '), *condition_params]
      scoped = self.where(conditions_compiled).order("#{paginated_options[:order_column]} #{paginated_options[:order]}")

      if paginated_options[:use_cursor]
        # Store has_next_page on the relationship as paginated_meta if we are doing cursor pagination
        # As we are doing cursor pagination, the scoped is already bigger or smaller than the cursor (offset is 0 for the query)
        # We offset by the page we are fetching, and check if there are more models
        has_next_page = scoped.offset(paginated_options[:per_page]).count > 0
        scoped.send(:paginated_meta=, {has_next_page: has_next_page})
      else
        # Store the total number of pages on the relationship as paginated_meta if we doing page pagination
        total_objects = scoped.count
        total_pages = total_objects.to_f / paginated_options[:per_page]
        total_pages += 1 if total_objects.to_f % paginated_options[:per_page] > 0
        paginated_meta =  {
          :total_pages => total_pages.to_i,
          :has_next_page => paginated_options[:page] < total_pages.to_i
        }
        scoped.send(:paginated_meta=, paginated_meta)
      end

      # Return the right page with offset and limit
     scoped.limit(paginated_options[:per_page]).offset(offset)
    end

    # Getter for paginated_meta
    def paginated_meta
      @paginated_meta || {}
    end

    private

    # Private setter for paginated_meta
    def paginated_meta=(value)
      @paginated_meta = value
    end

    # Returns the conditions and condition_params for filtering with greater_than, greater_than_or_equal_to, smaller_than, smaller_than_or_equal_to
    def greater_smaller_conditions(option, operator_type, sql_base_class, model_attributes)
      raise Paginated::InvalidPaginationOptions, "'#{operator_type}' must be a hash" unless option.is_a?(Hash)

      conditions = []
      condition_params = []

      option.each do |column_name, value|
        # Verify the column exists on the model and it is numeric or date_time
        raise Paginated::InvalidPaginationOptions, "'#{column_name}' is not a valid column name for '#{operator_type}'" unless model_attributes.include?(column_name.to_s)
        raise Paginated::InvalidPaginationOptions, "'#{column_name}' is not a valid column for '#{operator_type}'- column must be numeric or date_time" unless [:integer, :float, :datetime].include?(self.base_class.columns_hash[column_name.to_s].type)

        operator = case operator_type
                     when 'greater_than'
                       '>'
                     when 'greater_than_or_equal_to'
                       '>='
                     when 'smaller_than'
                       '<'
                     when 'smaller_than_or_equal_to'
                       '<='
                   end

        conditions << "#{sql_base_class}.#{column_name} #{operator} ?"

        # If the column type is datetime, we need to convert the value to ruby datetime
        column_type = self.base_class.columns_hash[column_name.to_s].type
        value =  value.to_datetime if column_type == :datetime

        condition_params << value
      end

      [conditions, condition_params]
    end
  end
end

# Extend Array to store paginated_meta
# We use this when we serialize object to store the paginated_meta, and then respond with it
class Array
  attr_accessor :paginated_meta
end
