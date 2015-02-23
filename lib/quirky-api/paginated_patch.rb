# Extend ActiveRecord::Relation with pagination
class ActiveRecord::Relation

  def paginated(paginated_options={})
    # Convert all non-string values to the right format
    case paginated_options[:use_cursor]
      when 'true', true
        paginated_options[:use_cursor] = true
      when 'false', false
        paginated_options[:use_cursor] = false
      else
        raise 'use_cursor can only be true of false' if paginated_options[:use_cursor].present?
    end
    paginated_options[:page] = paginated_options[:page].to_i if paginated_options[:page].present?
    paginated_options[:per_page] = paginated_options[:per_page].to_i if paginated_options[:per_page].present?

    raise 'can not do both cursor pagination and page pagination' if paginated_options[:use_cursor].present? && paginated_options[:page].present?

    # If we are not doing cursor pagination, we must have page. If we don't have it - we assume 1
    paginated_options[:page] = paginated_options[:page] || 1 unless paginated_options[:use_cursor]

    raise 'page must be 1 or bigger' if paginated_options[:page].present? && paginated_options[:page] < 1
    raise "order can only be 'asc', 'ASC', 'desc', 'DESC' (or nil which will default to 'ASC')" if paginated_options[:order].present? && !%w(asc ASC desc DESC).include?(paginated_options[:order])

    # The base class we will use for the sql statements
    sql_base_class = self.base_class.to_s.pluralize.downcase

    # Keep track of the attributes the model has that we can run sql on
    model_attributes = []

    # All the schema attributes
    model_attributes += self.base_class.column_names

    # If we have psql hstores or json stores add those too
    model_attributes += self.base_class.stored_attributes.values

    model_attributes.flatten!

    # If we have order_column - raise error if order_column is for a column that doesn't exist
    if paginated_options[:order_column].present?
      raise "can not sort by '#{paginated_options[:order_column]}' as such attribute or store accessor does not exist" unless model_attributes.include?(paginated_options[:order_column])

      # Raise error if :order_column is not float, integer or date_time column, as we can not sort by it
      # Excluding psql store columns, as their type is determined by the validations, and we can not automatically infer it
      unless self.base_class.stored_attributes.values.include?(paginated_options[:order_column])
        allowed_types = [:integer, :float, :datetime]
        requested_column_type = self.base_class.columns_hash[paginated_options[:order_column].to_s].type
        unless allowed_types.include?(requested_column_type)
          raise "can not order by column of type '#{requested_column_type}'"
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
      raise "'values_in' must be a hash" unless paginated_options[:values_in].is_a?(Hash)

      paginated_options[:values_in].each do |column_name, values|
        # Verify the column exists on the model
        raise "'#{column_name}' is not a valid column name for values_in" unless model_attributes.include?(column_name.to_s)

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
      raise "'values_not_in' must be a hash" unless paginated_options[:values_not_in].is_a?(Hash)

      paginated_options[:values_not_in].each do |column_name, values|
        # Verify the column exists on the model
        raise "'#{column_name}' is not a valid column name for values_not_in" unless model_attributes.include?(column_name.to_s)

        conditions << "#{sql_base_class}.#{column_name} NOT IN (?)"

        # If we have a single value, convert it to array
        values_in = values.is_a?(Array) ? values : [values]

        # If the column type is datetime, we need to convert the values to ruby datetime values
        column_type = self.base_class.columns_hash[column_name.to_s].type
        values_in.collect!{|value| value.to_datetime} if column_type == :datetime

        condition_params << values_in
      end
    end

    # Join the conditions and get the correctly scoped objects
    conditions_compiled = [conditions.join(' AND '), *condition_params]
    scoped = self.where(conditions_compiled).order("#{paginated_options[:order_column]} #{paginated_options[:order]}")

    # Store the total number of pages on the relationship
    total_objects = scoped.count
    total_pages = total_objects.to_f / paginated_options[:per_page]
    total_pages += 1 if total_objects.to_f % paginated_options[:per_page] > 0

    scoped.send(:paginated_meta=, {total_pages: total_pages.to_i})

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

end

# extend Array to store paginated_meta
class Array

  attr_accessor :paginated_meta

end
