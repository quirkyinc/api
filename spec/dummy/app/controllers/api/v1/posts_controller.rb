# encoding: utf-8

require 'quirky-api/controller'

class Api::V1::PostsController < QuirkyApi::Base
  def index
    @posts = paginate(Post.all)
    pagination_headers(@posts, url: [:api, :v1, :posts])
    respond_with @posts
  end

  def cursor
    posts = Post.order('id').all
    @posts, @next_cursor, @prev_cursor = paginate_with_cursor(posts)
    cursor_pagination_headers(posts, @next_cursor, @prev_cursor, url: [:api, :v1, :posts])
    respond_with @posts
  end

  def reverse_cursor
    posts = Post.order('id DESC').all
    @posts, @next_cursor, @prev_cursor = paginate_with_cursor(posts, reverse: true)
    cursor_pagination_headers(posts, @next_cursor, @prev_cursor, url: [:api, :v1, :posts])
    respond_with @posts
  end
end
