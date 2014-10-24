# encoding: utf-8

require 'quirky-api/controller'

class Api::V1::PostsController < QuirkyApi::Base
  def index
    @posts = paginate(Post.all)
    pagination_headers(@posts, url: [:api, :v1, :posts])
    respond_with @posts
  end

  def cursor
    @posts, @cursor = paginate_with_cursor(Post.all)
    cursor_pagination_headers(Post.all, @cursor, url: [:api, :v1, :posts])
    respond_with @posts
  end
end
