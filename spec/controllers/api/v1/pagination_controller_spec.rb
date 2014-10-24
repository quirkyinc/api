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
    before { FactoryGirl.create_list(:random_post, 12) }

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
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?cursor=11>; rel="next"')
      end

      it 'should include additional request params' do
        get :cursor, order: 'name', format: :json
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?cursor=11&order=name>; rel="next"')
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
        expect(response.headers['Link']).to eq('<http://test.host/api/v1/posts?cursor=7&per_page=6>; rel="next"')
      end
    end
  end

end
