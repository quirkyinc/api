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

    # If we have order_column - raise error if order_column is for a column that doesn't exist
    if paginated_options[:order_column].present?
      allowed_attributes = []

      # All the schema attributes
      allowed_attributes += self.base_class.column_names

      # If we have psql hstores or json stores add those too
      allowed_attributes += self.base_class.stored_attributes.values

      allowed_attributes.flatten!
      raise "can not sort by '#{paginated_options[:order_column]}' as such attribute or store accessor does not exist" unless allowed_attributes.include?(paginated_options[:order_column])

      # Raise error if :order_column is not float, integer or date_time column, as we can not sort by it
      # Excluding psql store columns, as their type is determined by the validations, and we can not automatically infer it
      unless self.base_class.stored_attributes.values.include?(paginated_options[:order_column])
        allowed_types = [:integer, :float, :datetime]
        requested_column_type = self.base_class.columns_hash[paginated_options[:order_column]].type
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
        conditions << "#{self.base_class.to_s.pluralize.downcase}.#{paginated_options[:order_column]} #{direction} ?"

        # If the column type is datetime, we need to convert the to datetime
        cursor = paginated_options[:cursor]
        requested_column_type = self.base_class.columns_hash[paginated_options[:order_column]].type
        cursor = cursor.to_datetime if requested_column_type == :datetime
        condition_params << cursor
      end

    # If we are doing page-pagination
    else
      offset = (paginated_options[:page] - 1) * paginated_options[:per_page]
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
