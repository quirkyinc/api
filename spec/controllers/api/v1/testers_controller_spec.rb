# encoding: utf-8

require 'spec_helper'

describe Api::V1::TestersController, type: :controller do
  describe 'GET #as_one' do
    before { @tester = FactoryGirl.create(:tester, name: 'Tester', last_name: 'Atqu') }

    it 'returns one' do
      get :as_one, format: :json
      expect(response.body).to eq({
        id: 1,
        name: 'Tester',
        product: nil
      }.to_json)
    end
  end

  describe 'GET #as_true' do
    it 'returns true' do
      get :as_true
      expect(response.body).to eq("true")
    end
  end

  describe 'GET #as_false' do
    it 'returns false' do
      get :as_false
      expect(response.body).to eq("false")
    end
  end

  describe 'GET #as_nil' do
    it 'returns a null object' do
      get :as_nil
      expect(response.body).to eq("null")
    end
  end

  describe 'GET #as_hash' do
    it 'returns a hash' do
      get :as_hash
      expect(response.body).to eq({
        one: 'two',
        three: 'four'
      }.to_json)
    end
  end

  describe 'GET #as_arr' do
    it 'returns an array' do
      get :as_arr
      expect(response.body).to eq(%w(one two three).to_json)
    end
  end

  describe 'GET #as_str' do
    it 'returns a string' do
      get :as_str, format: 'json'
      expect(response.body).to eq('one')
    end
  end

  describe 'GET #single_as_arr' do
    before { @tester = FactoryGirl.create(:tester, name: 'Tester', last_name: 'Atqu') }
    it 'returns an array with one element' do
      get :single_as_arr, format: 'json'
      expect(response.body).to eq([{
        id: 1,
        name: 'Tester',
        product: nil
      }].to_json)
    end
  end

  describe 'GET #errors' do
    before do
      @one = FactoryGirl.create(:tester, name: 'John', last_name: 'Smith')
    end

    describe 'with a standard exception' do
      it 'returns the actual exception' do
        allow(controller)
          .to receive(:errors)
          .and_raise(StandardError.new('Exception'))

        get :errors
        expect(response.body).to eq({ errors: 'Something went wrong.' }.to_json)
      end
    end

    describe 'with an exception handler that raises the error' do
      it 'raises the error' do
        allow(controller)
          .to receive(:errors)
          .and_raise(StandardError.new('Blah'))

        allow(QuirkyApi).to receive(:exception_handler).and_return(->(e) { raise e })

        expect { get :errors }.to raise_error('Blah')
      end
    end

    describe 'with CanCan::AccessDenied' do
      it 'returns 401 unauthorized' do
        CanCan = Class.new(Exception)
        CanCan::AccessDenied = Class.new(Exception)
        allow(controller)
          .to receive(:errors)
          .and_raise(CanCan::AccessDenied.new('Unauthorized'))

        get :errors
        expect(response.body).to eq({ errors: 'You are not authorized to do that.' }.to_json)
        expect(response.status).to eq 401
      end
    end

    describe 'with an invalid record' do
      it 'returns 400 bad request' do
        get :invalid_request
        expect(response.body).to eq({
          errors: {
            name: ["Name can't be blank"]
          }
        }.to_json)
        expect(response.status).to eq 400
      end
    end

    describe 'with a not-found record' do
      it 'returns 404 not found' do
        allow(controller)
          .to receive(:errors)
          .and_raise(ActiveRecord::RecordNotFound.new('Not Found'))

        get :errors
        expect(response.body).to eq({
          errors: 'Not found.'
        }.to_json)
        expect(response.status).to eq 404
      end
    end

    describe 'with a not-unique record' do
      it 'returns 409 conflict' do
        allow(controller)
          .to receive(:errors)
          .and_raise(ActiveRecord::RecordNotUnique.new('Not Unique.', nil))

        get :errors
        expect(response.body).to eq({ errors: 'Record not unique.' }.to_json)
        expect(response.status).to eq 409
      end
    end
  end

  describe 'GET #index' do
    before do
      @one = FactoryGirl.create(:tester, name: 'Mike', last_name: 'Sea')
      @two = FactoryGirl.create(:tester, name: 'Tom', last_name: 'Hanks')
      @product = FactoryGirl.create(:product)
      get :index, format: 'json'
    end

    # product_serialized has no serializer, so should show up as raw fields.
    # It is also a default_association so should always show up.
    let(:product_serialized) do
      {
        product: {
          id: @product.id,
          name: @product.name,
          desc: @product.desc,
          created_at: @product.created_at,
          updated_at: @product.updated_at
        }
      }
    end

    let(:post_serialized) do
      {
        post: {
          id: 1,
          title: 'Hi',
          blurb: "What's up?"
        }
      }
    end

    it 'responds success' do
      expect(response).to be_success
    end

    it 'responds with data' do
      expect(response.body).to eq([
        {
          id: 1,
          name: 'Mike'
        }.merge(product_serialized),
        {
          id: 2,
          name: 'Tom'
        }.merge(product_serialized)
      ].to_json)
    end

    it 'responds to field inclusion' do
      get :index, format: 'json', fields: ['id']
      expect(response.body).to eq([
        {
          id: 1
        }.merge(product_serialized),
        {
          id: 2
        }.merge(product_serialized)
      ].to_json)
    end

    it 'responds to field exclusion' do
      get :index, format: 'json', exclude: ['id']
      expect(response.body).to eq([
        {
          name: 'Mike'
        }.merge(product_serialized),
        {
          name: 'Tom'
        }.merge(product_serialized)
      ].to_json)
    end

    context 'optional fields' do
      it 'responds to optional fields' do
        get :index, format: 'json', extra_fields: ['last_name']
        expect(response.body).to eq([
          {
            id: 1,
            name: 'Mike',
            last_name: 'Sea'
          }.merge(product_serialized),
          {
            id: 2,
            name: 'Tom',
            last_name: 'Hanks'
          }.merge(product_serialized)
        ].to_json)
      end

      context 'if warn_invalid_fields is true' do
        context 'and there is an envelope' do
          before do
            QuirkyApi.envelope = 'data'
          end

          after do
            QuirkyApi.envelope = nil
          end

          it 'throws a warning for bad optional fields' do
            allow(QuirkyApi).to receive(:warn_invalid_fields).and_return(true)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq({
             data: [
                {
                  id: 1,
                  name: 'Mike'
                }.merge(product_serialized),
                {
                  id: 2,
                  name: 'Tom'
                }.merge(product_serialized)
              ],
              warnings: [
                "The 'favorite_animal' field is not a valid optional field"
              ]
            }.to_json)
          end
        end

        context 'and there is no envelope' do
          before do
            QuirkyApi.envelope = nil
          end

          it 'does not show warnings' do
            allow(QuirkyApi).to receive(:warn_invalid_fields).and_return(true)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq([
              {
                id: 1,
                name: 'Mike'
              }.merge(product_serialized),
              {
                id: 2,
                name: 'Tom'
              }.merge(product_serialized)
            ].to_json)
          end
        end
      end

      context 'if warn_invalid_fields is falsey' do
        context 'and there is an envelope' do
          before do
            QuirkyApi.envelope = 'data'
          end

          after do
            QuirkyApi.envelope = nil
          end

          it 'throws no warning for bad optional fields' do
            allow(QuirkyApi).to receive(:warn_invalid_fields).and_return(false)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq({
              data: [
                {
                  id: 1,
                  name: 'Mike'
                }.merge(product_serialized),
                {
                  id: 2,
                  name: 'Tom'
                }.merge(product_serialized)
              ]
            }.to_json)
          end
        end

        context 'and there is no envelope' do
          before do
            QuirkyApi.envelope = nil
          end

          it 'throws no warning for bad optional fields' do
            allow(QuirkyApi).to receive(:warn_invalid_fields).and_return(false)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq([
              {
                id: 1,
                name: 'Mike'
              }.merge(product_serialized),
              {
                id: 2,
                name: 'Tom'
              }.merge(product_serialized)
            ].to_json)
          end
        end
      end
    end

    context 'associations', focus: true do
      it 'responds to associations' do
        FactoryGirl.create(:post)
        get :index, format: 'json', associations: ['post']
        expect(response.body).to eq([
          {
            id: 1,
            name: 'Mike'
          }.merge(product_serialized).merge(post_serialized),
          {
            id: 2,
            name: 'Tom'
          }.merge(product_serialized).merge(post_serialized)
        ].to_json)
      end

      context 'if validate_associations is true' do
        context 'if you specify an invalid association' do
          it 'returns an error' do
            allow(QuirkyApi).to receive(:validate_associations).and_return(true)
            get :index, format: 'json', associations: ['octopus']
            expect(response.body).to eq({
              errors: "The 'octopus' association does not exist."
            }.to_json)
          end
        end
      end
      context 'if validate_associations is false' do
        context 'if you specify an invalid association' do
          it 'does not throw an error' do
            allow(QuirkyApi).to receive(:validate_associations).and_return(nil)
            get :index, format: 'json', associations: ['octopus']
            expect(response.body).to eq([
              {
                id: 1,
                name: 'Mike'
              }.merge(product_serialized),
              {
                id: 2,
                name: 'Tom'
              }.merge(product_serialized)
            ].to_json)
          end
        end
      end

      context 'sub fields' do
        it 'returns fields from an association' do
          FactoryGirl.create(:post)
          get :index, format: :json, associations: ['post'], post_fields: ['id']
          expect(response.body).to eq([
            {
              id: 1,
              name: 'Mike'
            }.merge(product_serialized).merge(
              post: {
                id: 1
              }
            ),
            {
              id: 2,
              name: 'Tom'
            }.merge(product_serialized).merge(
              post: {
                id: 1
              }
            )
          ].to_json)
        end
      end

      context 'sub optional fields' do
        it 'returns optional fields from an association' do
          FactoryGirl.create(:post)
          get :index, format: :json, associations: ['post'],
                      post_extra_fields: ['joke']
          expect(response.body).to eq([
            {
              id: 1,
              name: 'Mike'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                joke: 'Why was six afraid of seven?'
              }
            ),
            {
              id: 2,
              name: 'Tom'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                joke: 'Why was six afraid of seven?'
              }
            )
          ].to_json)
        end
      end

      context 'sub associations' do
        it 'returns associations from an association' do
          FactoryGirl.create(:post)
          get :index, format: :json, associations: ['post'],
                      post_associations: ['myself']
          expect(response.body).to eq([
            {
              id: 1,
              name: 'Mike'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                myself: {
                  id: 1,
                  title: 'Hi',
                  blurb: "What's up?"
                }
              }
            ),
            {
              id: 2,
              name: 'Tom'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                myself: {
                  id: 1,
                  title: 'Hi',
                  blurb: "What's up?"
                }
              }
            )
          ].to_json)
        end
      end
    end
  end
end
