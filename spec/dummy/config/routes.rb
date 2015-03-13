# encoding: utf-8

Dummy::Application.routes.draw do
  namespace :api, format: 'json' do
    namespace :v1 do
      resources :testers do
        collection do
          get 'errors'
          get 'invalid_request'
          get 'not_unique'
          get 'as_one'
          get 'as_true'
          get 'as_false'
          get 'as_nil'
          get 'as_hash'
          get 'as_arr'
          get 'as_str'
          get 'single_as_arr'
          get 'with_status'
          get 'with_hash_elements'
          get 'with_bool_elements'
          get 'with_string_elements'
          get 'with_arr_elements'
          get 'with_cache_serialized'
          get 'with_callback'
          get 'with_bad_verify_perms'
        end
      end

      resources :posts do
        collection do
          get 'cursor'
          get 'reverse_cursor'
        end
      end
    end
  end
end
