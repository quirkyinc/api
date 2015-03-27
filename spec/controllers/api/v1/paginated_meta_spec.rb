require 'spec_helper'

# We create a fake controller to test the pagination
class TestApiController < ::QuirkyApi::Base
end

RSpec.describe TestApiController, :type => :controller do
  controller(TestApiController) do
    def index
      @inventions = Invention.all.paginated(params[:paginated_options][:inventions])
      respond_with({inventions: serialize(@inventions)})
    end
  end

  describe "Paginated response" do
    let(:inventions) { create_list(:invention, 100) }
    before do
      inventions
    end

    context "page pagination" do
      it "adds the pagination_meta with total_pages to the response" do
        get :index,
            format: :json,
            paginated_options: {inventions: {per_page: 8}}

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['total']).to eq 100
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['page']).to eq 1
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['per_page']).to eq 8
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['total_pages']).to eq 13
      end

      it "adds the pagination_meta with has_next_page to the response when there is a next page" do
        get :index,
            format: :json,
            paginated_options: {inventions: {page: 9, per_page: 10}}

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['total_pages']).to eq 10
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['has_next_page']).to eq true
      end

      it "adds the pagination_meta with has_next_page to the response when there is no next page" do
        get :index,
            format: :json,
            paginated_options: {inventions: {page: 10, per_page: 10}}

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['total_pages']).to eq 10
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['has_next_page']).to eq false
      end
    end

    context "cursor pagination" do
      it "adds the pagination_meta with has_next_page to the response in cursor pagination and does not add total_pages" do
        get :index,
            format: :json,
            paginated_options: {inventions: {
              use_cursor: true,
              per_page: 8
            }}

        expect(response.status).to eq 200
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['has_next_page']).to eq true
        expect(JSON.parse(response.body)['paginated_meta']['inventions']['total_pages']).to eq nil
      end
    end

    it "responds with the correct paginated objects" do
      get :index,
          format: :json,
          paginated_options: {inventions: {per_page: 8}}

      expect(response.status).to eq 200
      expect(JSON.parse(response.body)['inventions'].length).to eq 8
    end

    it "responds with 400 and errors if the pagination_options are not correct" do
      get :index,
          format: :json,
          paginated_options: {inventions: {use_cursor: 'wrong'}}
      expect(response.status).to eq 400
      response_body = JSON.parse(response.body)
      expect(response_body['errors']['paginated_options']).to eq "use_cursor can only be true of false"
    end
  end
end
