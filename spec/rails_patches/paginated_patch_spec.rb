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

    context "paginated_meta - total_pages" do
      it "provides a getter for paginated_meta on ActiveRecord::Relation" do
        inventions = Invention.all.limit(2)
        expect(inventions).to respond_to :paginated_meta
      end

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

        cursor = Invention.all.order('creator_id ASC').limit(@per_page).pluck(:creator_id).sample(1).first

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

        cursor = Invention.all.order('creator_id DESC').limit(@per_page).pluck(:creator_id).sample(1).first

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
          i.update_attribute('updated_at', rand_arr.pop.seconds.ago)
        end

        cursor = Invention.all.order('updated_at ASC').limit(@per_page).pluck(:updated_at).sample(1).first

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
          i.update_attribute('updated_at', rand_arr.pop.seconds.ago)
        end

        cursor = Invention.all.order('updated_at DESC').limit(@per_page).pluck(:updated_at).sample(1).first

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
  end
end
