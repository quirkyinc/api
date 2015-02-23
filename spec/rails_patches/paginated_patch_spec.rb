require File.expand_path('../../spec_helper', __FILE__)

describe Invention do
  let(:inventions) { create_list(:invention, 100) }
  before do
    inventions
  end

  describe ".paginated" do
    it ".paginated extends ActiveRecord::Relation" do
      expect(Invention.all).to respond_to :paginated
      expect(Invention.all.paginated({page: 1}).class).to eq Invention::ActiveRecord_Relation
    end

    it "adds paginated_meta to Array class" do
      arr = []
      expect(arr).to respond_to :paginated_meta
      arr.paginated_meta = 'blah'
      expect(arr.paginated_meta).to eq 'blah'
    end

    context "invalid arguments" do
      it "raises an error if provided use_cursor which is not true or false" do
        paginated_options = {
          use_cursor: 'something',
          page: 2
        }
        expect{Invention.all.paginated(paginated_options)}.to raise_error 'use_cursor can only be true of false'
      end

      it "raises an error if provided user_cursor and page" do
        paginated_options = {
          use_cursor: true,
          page: 2
        }
        expect{Invention.all.paginated(paginated_options)}.to raise_error 'can not do both cursor pagination and page pagination'
      end

      it "raises an error if specified page is smaller than 1" do
        paginated_options = {
          use_cursor: false,
          page: -1
        }
        expect{Invention.all.paginated(paginated_options)}.to raise_error 'page must be 1 or bigger'
      end

      it "raises an error for invalid string as order" do
        paginated_options = {
          page: 1,
          per_page: 20,
          order: 'wrong'
        }
        expect{Invention.all.paginated(paginated_options)}.to raise_error "order can only be 'asc', 'ASC', 'desc', 'DESC' (or nil which will default to 'ASC')"
      end

      it "raises an error if the order_column does not exist as an attribute or store accessor for this class" do
        paginated_options = {
          page: 1,
          per_page: 50,
          order_column: 'no_such_column'
        }
        expect{Invention.all.paginated(paginated_options)}.to raise_error "can not sort by 'no_such_column' as such attribute or store accessor does not exist"
      end

      it "raises an error if the order_column is not float, integer or date_time type" do
        paginated_options = {
          page: 1,
          per_page: 10,
          order_column: 'title'
        }
        expect{Invention.all.paginated(paginated_options)}.to raise_error "can not order by column of type 'string'"
      end
    end

    context ":order, :order_column, :per_page " do
      it "orders by 'id ASC' if not specified" do
        paginated_options = {
          page: 1,
          per_page: 20
        }
        expect(Invention.all.paginated(paginated_options)).to eq Invention.all.order('id ASC').limit(20).offset(0)
      end

      it "orders ASC or DESC as specified in :order" do
        paginated_options = {
          page: 1,
          per_page: 10,
          order: 'ASC'
        }
        expect(Invention.all.paginated(paginated_options)).to eq Invention.all.order('id ASC').limit(10).offset(0)

        paginated_options = {
          page: 1,
          per_page: 10,
          order: 'DESC'
        }
        expect(Invention.all.paginated(paginated_options)).to eq Invention.all.order('id DESC').limit(10).offset(0)
      end

      it "orders by the columns specified in :order_column" do
        rand_arr = (1..1000).to_a.shuffle
        inventions.dup.each do |i|
          i.update_attribute('creator_id', rand_arr.pop)
        end

        paginated_options = {
          page: 1,
          per_page: 50,
          order_column: 'creator_id'
        }
        expect(Invention.all.paginated(paginated_options)).to eq Invention.all.order('creator_id ASC').limit(50).offset(0)
      end

      it "limits by the :per_page specified" do
        limit = rand(1..inventions.length)
        paginated_options = {
          page: 1,
          per_page: limit
        }
        expect(Invention.all.paginated(paginated_options)).to eq Invention.all.order('id ASC').limit(limit).offset(0)
      end
    end

    context "paginated_meta" do
      it "provides a getter for paginated_meta on ActiveRecord::Relation" do
        inventions = Invention.all.limit(2)
        expect(inventions).to respond_to :paginated_meta
      end

      context "has_next_page" do
        it "cursor pagination: sets the correct has_next_page in pagination_meta on the ActiveRecord::Relation" do
          id = Invention.order('inventions.id ASC').pluck(:id)[Invention.count - 5]
          paginated_options = {
            use_cursor: true,
            cursor: id,
            per_page: 3
          }
          inventions = Invention.all.paginated(paginated_options)
          expect(inventions.paginated_meta[:has_next_page]).to eq true

          id = Invention.last.id
          paginated_options = {
            use_cursor: true,
            cursor: id,
            per_page: 10
          }
          inventions = Invention.order('inventions.id ASC').paginated(paginated_options)
          expect(inventions.paginated_meta[:has_next_page]).to eq false
        end

        it "page pagination: sets the correct has_next_page in pagination_meta on the ActiveRecord::Relation" do
          paginated_options = {
            page: 9,
            per_page: 10
          }
          inventions = Invention.all.paginated(paginated_options)
          expect(inventions.paginated_meta[:has_next_page]).to eq true

          paginated_options = {
            page: 10,
            per_page: 10
          }
          inventions = Invention.all.paginated(paginated_options)
          expect(inventions.paginated_meta[:has_next_page]).to eq false
        end
      end

      context "total_pages - for page pagination" do
        it "sets the correct total_pages in pagination_meta on the ActiveRecord::Relation if it is an exact number" do
          paginated_options = {
            page: 2,
            per_page: 5
          }
          inventions = Invention.all.paginated(paginated_options)
          expect(inventions.paginated_meta[:total_pages]).to eq 20
        end

        it "sets the correct total_pages in pagination_meta on the ActiveRecord::Relation if the last page is less than full" do
          paginated_options = {
            page: 2,
            per_page: 8
          }
          inventions = Invention.all.paginated(paginated_options)
          expect(inventions.paginated_meta[:total_pages]).to eq 13
        end

        it "does not store total_pages for cursor pagination" do
          paginated_options = {
            use_cursor: true,
            per_page: 8
          }
          inventions = Invention.all.paginated(paginated_options)
          expect(inventions.paginated_meta[:total_pages]).not_to be
        end
      end
    end

    context "Page Pagination" do
      it "offsets correctly based on the :page requested" do
        page = rand(1..5)
        paginated_options = {
          page: page,
          per_page: 20
        }
        offset = (page - 1) * 20
        expect(Invention.all.paginated(paginated_options)).to eq Invention.all.order('id ASC').limit(20).offset(offset)
      end

      it "it sets page to 1 if not doing cursor pagination and not sending page" do
        paginated_options = {
          per_page: 20
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.order('id ASC').limit(20).to_a
      end
    end

    context "Cursor Pagination" do
      before do
        @per_page = rand(1..inventions.length)
      end

      it "ASC - returns the first batch if no cursor sent" do
        paginated_options = {
          use_cursor: true,
          per_page: @per_page
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.order('id ASC').limit(@per_page).to_a
      end

      it "DESC - returns the first batch if no cursor sent" do
        paginated_options = {
          use_cursor: true,
          per_page: @per_page,
          order: 'desc'
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.order('id desc').limit(@per_page).to_a
      end

      it "ASC - returns the next batch after the cursor sent" do
        rand_arr = (1..1000).to_a.shuffle
        inventions.dup.each do |i|
          i.update_attribute('creator_id', rand_arr.pop)
        end

        cursor = Invention.all.order('creator_id ASC').limit(@per_page).pluck(:creator_id).sample

        paginated_options = {
          use_cursor: true,
          order_column: 'creator_id',
          per_page: @per_page,
          cursor: cursor
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.where('inventions.creator_id > ?', cursor).order('creator_id ASC').limit(@per_page).to_a
      end

      it "DESC - returns the next batch after the cursor sent" do
        rand_arr = (1..1000).to_a.shuffle
        inventions.dup.each do |i|
          i.update_attribute('creator_id', rand_arr.pop)
        end

        cursor = Invention.all.order('creator_id DESC').limit(@per_page).pluck(:creator_id).sample

        paginated_options = {
          use_cursor: true,
          order_column: 'creator_id',
          order: 'DESC',
          per_page: @per_page,
          cursor: cursor
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.where('inventions.creator_id < ?', cursor).order('creator_id DESC').limit(@per_page).to_a
      end

      it "ASC works with DateTime columns send from backbone" do
        rand_arr = (1..1000).to_a.shuffle
        inventions.dup.each do |i|
          i.update_attribute('updated_at', rand_arr.pop.minutes.ago)
        end

        cursor = Invention.all.order('updated_at ASC').limit(@per_page).pluck(:updated_at).sample

        paginated_options = {
          use_cursor: true,
          order_column: 'updated_at',
          per_page: @per_page,
          cursor: cursor.as_json
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.where('inventions.updated_at > ?', cursor).order('updated_at ASC').limit(@per_page).to_a
      end

      it "DESC works with DateTime columns send from backbone" do
        rand_arr = (1..1000).to_a.shuffle
        inventions.dup.each do |i|
          i.update_attribute('updated_at', rand_arr.pop.minutes.ago)
        end

        cursor = Invention.all.order('updated_at DESC').limit(@per_page).pluck(:updated_at).sample

        paginated_options = {
          use_cursor: true,
          order_column: 'updated_at',
          order: 'DESC',
          per_page: @per_page,
          cursor: cursor.as_json
        }
        expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.all.where('inventions.updated_at < ?', cursor).order('updated_at DESC').limit(@per_page).to_a
      end
    end

    context "Filters" do
      context "values_in" do
        it "filters by values_in for each column specified" do
          inventions.each do |i|
            i.update_attribute('state', ['a', 'b', 'c', 'd'].sample)
          end
          per_page = rand(1..100)
          paginated_options = {
            page: 1,
            per_page: per_page,
            values_in: {
              state: ['a', 'c']
            }
          }
          expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.where('inventions.state IN (?)', ['a', 'c']).limit(per_page).to_a
        end

        it "filters by values_in if given a single value and not an array of values" do
          inventions.each do |i|
            i.update_attribute('state', ['a', 'b', 'c', 'd'].sample)
          end
          per_page = rand(1..100)
          paginated_options = {
            page: 1,
            per_page: per_page,
            values_in: {
              state: 'b'
            }
          }
          expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.where('inventions.state IN (?)', ['b']).limit(per_page).to_a
        end

        it "works for date_time columns" do
          rand_arr = (1..1000).to_a.shuffle
          inventions.dup.each do |i|
            i.update_attribute('updated_at', rand_arr.pop.minutes.ago)
          end

          rand = rand(1..100)
          inventions_to_get = Invention.all.sample(rand)

          paginated_options = {
            page: 1,
            per_page: 100,
            values_in: {
              updated_at: inventions_to_get.map(&:updated_at).as_json
            }
          }
          expect(Invention.all.paginated(paginated_options).to_a.sort_by{|i| i.id }).to eq inventions_to_get.to_a.sort_by{|i| i.id }
        end

        it "raises an error if the column name in values_in doesn't exist" do
          paginated_options = {
            values_in: {
              not_there: ['a', 'c']
            }
          }
          expect{Invention.all.paginated(paginated_options)}.to raise_error "'not_there' is not a valid column name for 'values_in'"
        end

        it "raises an error if values_in is not a hash" do
          paginated_options = {
            values_in: 'some string'
          }
          expect{Invention.all.paginated(paginated_options)}.to raise_error "'values_in' must be a hash"
        end
      end

      context "values_not_in" do
        it "filters by values_not_in for each column specified" do
          inventions.each do |i|
            i.update_attribute('state', ['a', 'b', 'c', 'd'].sample)
          end
          per_page = rand(1..100)
          paginated_options = {
            page: 1,
            per_page: per_page,
            values_not_in: {
              state: ['a', 'c']
            }
          }
          expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.where('inventions.state NOT IN (?)', ['a', 'c']).limit(per_page).to_a
        end

        it "filters by values_not_in if given a single value and not an array of values" do
          inventions.each do |i|
            i.update_attribute('state', ['a', 'b', 'c', 'd'].sample)
          end
          per_page = rand(1..100)
          paginated_options = {
            page: 1,
            per_page: per_page,
            values_not_in: {
              state: 'b'
            }
          }
          expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.where('inventions.state NOT IN (?)', ['b']).limit(per_page).to_a
        end

        it "works for date_time columns" do
          rand_arr = (1..1000).to_a.shuffle
          inventions.dup.each do |i|
            i.update_attribute('updated_at', rand_arr.pop.minutes.ago)
          end

          rand = rand(1..100)
          inventions_not_to_get = Invention.all.sample(rand)
          inventions_to_get = Invention.all.where('id NOT IN (?)', inventions_not_to_get.map(&:id))

          paginated_options = {
            page: 1,
            per_page: 100,
            values_not_in: {
              updated_at: inventions_not_to_get.map(&:updated_at).as_json
            }
          }
          expect(Invention.all.paginated(paginated_options).to_a.sort_by{|i| i.id }).to eq inventions_to_get.to_a.sort_by{|i| i.id }
        end

        it "raises an error if the column name in values_not_in doesn't exist" do
          paginated_options = {
            values_not_in: {
              not_there: ['a', 'c']
            }
          }
          expect{Invention.all.paginated(paginated_options)}.to raise_error "'not_there' is not a valid column name for 'values_not_in'"
        end

        it "raises an error if values_not_in is not a hash" do
          paginated_options = {
            values_not_in: 'some string'
          }
          expect{Invention.all.paginated(paginated_options)}.to raise_error "'values_not_in' must be a hash"
        end
      end
    end

    context "greater, greater_or_equal, smaller, smaller_or_equal" do
      let(:operator_types) { %w(greater greater_or_equal smaller smaller_or_equal) }

      it "filters by operator_type for each column specified" do
        operator_types.each do |operator_type|
          cut_off = Invention.all.pluck(:id).sample

          paginated_options = {
            page: 1,
            per_page: 100,
            operator_type.to_sym => {
              id: cut_off
            }
          }
          operator = case operator_type
                       when 'greater'
                         '>'
                       when 'greater_or_equal'
                         '>='
                       when 'smaller'
                         '<'
                       when 'smaller_or_equal'
                         '<='
                     end
          expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.where("inventions.id #{operator} ?", cut_off).order('id ASC').to_a
        end
      end

      it "works for date_time columns" do
        operator_types.each do |operator_type|
          rand_arr = (1..100).to_a.shuffle
          inventions.dup.each do |i|
            i.update_attribute('updated_at', rand_arr.pop.minutes.ago)
          end
          cut_off = Invention.all.pluck(:updated_at).sample

          paginated_options = {
            page: 1,
            per_page: 100,
            order_column: 'updated_at',
            operator_type.to_sym => {
              updated_at: cut_off.as_json
            }
          }
          operator = case operator_type
                       when 'greater'
                         '>'
                       when 'greater_or_equal'
                         '>='
                       when 'smaller'
                         '<'
                       when 'smaller_or_equal'
                         '<='
                     end
          expect(Invention.all.paginated(paginated_options).to_a).to eq Invention.where("inventions.updated_at #{operator} ?", cut_off).order('updated_at ASC').to_a
        end
      end

      context "raises the correct errors" do
        it "raises an error if the column name in greater doesn't exist" do
          operator_types.each do |operator_type|
            paginated_options = {
              operator_type.to_sym => {
                not_there: 22
              }
            }
            expect{Invention.all.paginated(paginated_options)}.to raise_error "'not_there' is not a valid column name for '#{operator_type}'"
          end
        end

        it "raises an error if greater is not a hash" do
          operator_types.each do |operator_type|
            paginated_options = {
              operator_type.to_sym => 'some string'
            }
            expect{Invention.all.paginated(paginated_options)}.to raise_error "'#{operator_type}' must be a hash"
          end
        end

        it "raises an error if the column is not numeric or date_time" do
          operator_types.each do |operator_type|
            paginated_options = {
              operator_type.to_sym => {
                title: 23
              }
            }
            expect{Invention.all.paginated(paginated_options)}.to raise_error "'title' is not a valid column for '#{operator_type}'- column must be numeric or date_time"
          end
        end
      end
    end
  end
end
