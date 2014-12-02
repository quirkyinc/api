# encoding: utf-8

require 'spec_helper'

describe Api::V1::PostsController, type: :controller do

  describe 'GET #index' do
    before { FactoryGirl.create_list(:random_post, 12) }

    it 'should return first 10 posts' do
      get :index, format: :json
      response_json = JSON.parse(response.body)
      expect(response_json.count).to eq(10)
    end

    it 'should set Total header' do
      get :index, format: :json
      expect(response.headers['Total']).to eq('12')
    end

    context 'Link header' do
      it 'should include next and last' do
        get :index, format: :json
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?page=2>; rel="next", <http://test.host/api/v1/posts?page=2>; rel="last"')
      end

      it 'should include additional request params' do
        get :index, order: 'name', format: :json
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?order=name&page=2>; rel="next", <http://test.host/api/v1/posts?order=name&page=2>; rel="last"')
      end

      it 'should include last page' do
        FactoryGirl.create_list(:random_post, 12)
        get :index, format: :json
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?page=2>; rel="next", <http://test.host/api/v1/posts?page=3>; rel="last"')
      end

      it 'should include first, next, prev, and last pages' do
        FactoryGirl.create_list(:random_post, 12)
        get :index, page: 2, format: :json
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?page=1>; rel="first", <http://test.host/api/v1/posts?page=3>; rel="next", <http://test.host/api/v1/posts?page=1>; rel="prev", <http://test.host/api/v1/posts?page=3>; rel="last"')
      end
    end

    context 'per_page param' do
      it 'should accept param' do
        get :index, per_page: 12, format: :json
        response_json = JSON.parse(response.body)
        expect(response_json.count).to eq(12)
      end

      it 'should include per_page in Link header' do
        get :index, per_page: 6, format: :json
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?page=2&per_page=6>; rel="next", <http://test.host/api/v1/posts?page=2&per_page=6>; rel="last"')
      end
    end
  end

  describe 'GET #cursor' do
    context 'link headers' do
      let!(:posts) { FactoryGirl.create_list(:random_post, 12) }

      it 'should return first 10 posts' do
        get :cursor, format: :json
        response_json = JSON.parse(response.body)
        expect(response_json.count).to eq(10)
      end

      it 'should set Total header' do
        get :cursor, format: :json
        expect(response.headers['Total']).to eq('12')
      end

      context 'Link header' do
        it 'should include next page' do
          get :cursor, format: :json
          next_cursor = assigns(:next_cursor)
          expect(response.headers['Link']).to eq("<http://test.host/api/v1/posts?cursor=#{next_cursor}>; rel=\"next\"")
        end

        it 'should include additional request params' do
          get :cursor, order: 'name', format: :json
          next_cursor = assigns(:next_cursor)
          expect(response.headers['Link']).to eq("<http://test.host/api/v1/posts?cursor=#{next_cursor}&order=name>; rel=\"next\"")
        end
      end

      context 'per_page param' do
        it 'should accept param' do
          get :cursor, per_page: 12, format: :json
          response_json = JSON.parse(response.body)
          expect(response_json.count).to eq(12)
        end

        it 'should include per_page in Link header' do
          get :cursor, per_page: 6, format: :json
          next_cursor = assigns(:next_cursor)
          expect(response.headers['Link']).to eq("<http://test.host/api/v1/posts?cursor=#{next_cursor}&per_page=6>; rel=\"next\"")
        end
      end
    end

    context 'cursor pagination for empty collection' do
      it 'should return empty collection and nil cursors for an empty collection' do
        get :cursor, format: :json
        expect(assigns(:posts).count).to eq(0)
        expect(assigns(:next_cursor)).to be_nil
        expect(assigns(:prev_cursor)).to be_nil
      end
    end

    context 'cursor_pagination' do
      let!(:posts) { FactoryGirl.create_list(:random_post, 12) }

      it 'should return expected results for first page with per_page specified' do
        get :cursor, per_page: 3, format: :json
        expect(assigns(:posts).count).to eq(3)
        expect(assigns(:posts)).to contain_exactly(posts[0], posts[1], posts[2])
        expect(assigns(:next_cursor)).to eq(posts[2].id + 1)
        expect(assigns(:prev_cursor)).to be_nil
      end

      it 'should return expected results for second page with per_page specified' do
        get :cursor, per_page: 3, cursor: posts[2].id + 1, format: :json
        expect(assigns(:posts).count).to eq(3)
        expect(assigns(:posts)).to contain_exactly(posts[3], posts[4], posts[5])
        expect(assigns(:next_cursor)).to eq(posts[5].id + 1)
        expect(assigns(:prev_cursor)).to eq(posts[0].id)
      end

      it 'should return expected results for last item with per_page specified' do
        get :cursor, per_page: 3, cursor: posts[11].id, format: :json
        expect(assigns(:posts).count).to eq(1)
        expect(assigns(:posts)).to contain_exactly(posts[11])
        expect(assigns(:next_cursor)).to be_nil
        expect(assigns(:prev_cursor)).to eq(posts[8].id)
      end
    end
  end

  describe 'GET #reverse_cursor' do
    let!(:posts) { FactoryGirl.create_list(:random_post, 12) }

    it 'should return expected results for first page for reversed collection with per_page specified' do
      get :reverse_cursor, per_page: 3, format: :json
      expect(assigns(:posts).count).to eq(3)
      expect(assigns(:posts)).to contain_exactly(posts[9], posts[10], posts[11])
      expect(assigns(:next_cursor)).to eq(posts[9].id - 1)
      expect(assigns(:prev_cursor)).to be_nil
    end

    it 'should return expected results for second page for reversed collection with per_page specified' do
      get :reverse_cursor, per_page: 3, cursor: posts[9].id - 1, format: :json
      expect(assigns(:posts).count).to eq(3)
      expect(assigns(:posts)).to contain_exactly(posts[8], posts[7], posts[6])
      expect(assigns(:next_cursor)).to eq(posts[6].id - 1)
      expect(assigns(:prev_cursor)).to eq(posts[11].id)
    end

    it 'should return expected results for last item for reversed collection with per_page specified' do
      get :reverse_cursor, per_page: 3, cursor: posts[0].id, format: :json
      expect(assigns(:posts).count).to eq(1)
      expect(assigns(:posts)).to contain_exactly(posts[0])
      expect(assigns(:next_cursor)).to be_nil
      expect(assigns(:prev_cursor)).to eq(posts[3].id)
    end
  end

end
