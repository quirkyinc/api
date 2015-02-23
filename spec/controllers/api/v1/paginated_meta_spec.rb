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

    it "adds the pagination_meta with total_pages to the response" do
      get :index,
          format: :json,
          paginated_options: {inventions: {per_page: 8}}

      expect(response.status).to eq 200
      expect(JSON.parse(response.body)['paginated_meta']['inventions']['total_pages']).to eq 13
    end

    it "responds with the correct paginated objects" do
      get :index,
          format: :json,
          paginated_options: {inventions: {per_page: 8}}

      expect(response.status).to eq 200
      expect(JSON.parse(response.body)['inventions'].length).to eq 8
    end
  end
end
