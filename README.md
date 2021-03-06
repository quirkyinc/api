# Quirky API

- [Explanation](#explanation)
- [Usage](#usage)
- [Rendering content](#rendering)
  - [Caveats](#response-caveats)
  - [Changing response status code](#changing-response-status-code)
  - [Top level elements](#top-level-elements)
- [`respond_with` second parameter options](#respond_with-second-parameter-options)
  - [status](#respond_with-second-parameter-options)
  - [associations](#respond_with-second-parameter-options)
  - [extra_fields](#respond_with-second-parameter-options)
  - [only](#respond_with-second-parameter-options)
  - [exclude](#respond_with-second-parameter-options)
  - [elements](#respond_with-second-parameter-options)
- [Serializers](#serializers)
  - [Attributes](#attributes)
  - [Optional fields](#optional-fields)
  - [Associations](#associations)
    - [Association filtering](#association-filtering)
  - [Caching data](#caching-data)
- [Serializing data](#serializing-data)
  - [`serialize` helper method](#serialize-helper-method)
  - [Manual serialization](#manual-serialization)
  - [Array serialization](#array-serialization)
- [QuirkyApi::Response::Pagination](#quirkyapiresponsepagination)
  - [`paginate_with_cursor`](#paginate_with_cursor)
  - [`cursor_pagination_headers`](#cursor_pagination_headers)

## Explanation

The `quirky-api` gem provides a library of useful tools and methods to help make API development easier.

All functionality is automatically included by adding `quirky-api` to your Gemfile:

```ruby
gem 'quirky-api'
```

## Usage

API controllers may be namespaced however you wish, but should always inherit from `QuirkyApi::Base`.  `QuirkyApi::Base` provides the helper methods and performance improvements essential to the API.

```ruby
module Api
  module V1
    class UsersController < QuirkyApi::Base
      def index
        respond_with User.all
      end
    end
  end
end
```

## Rendering content

Use `respond_with` to render content in the API.  `respond_with`, in the scope of `quirky-api`, is an abstraction that provides better integration with Active Model Serializers.  It also provides a [TODO number of options](#options) that make responding with dynamic content easier.

```ruby
module Api
  module V1
    class UsersController < QuirkyApi::Base
      def index
        respond_with User.paginate(page: 1 || params[:page], per_page: 15 || params[:per_page])
      end
    end
  end
end
```

`respond_with` always outputs content as JSON.  Objects are subsequently wrapped inside a `data` key, as below:

```json
{
  "data": [
    {
      "id": 1,
      "name": "Mike",
      "last_name": "Sea"
    },
    {
      "id": 2,
      "name": "Bob",
      "last_name": "McTestinstine"
    }
  ]
}
```

### Response caveats:

* If the content passed to `respond_with` is an array (of any type), regardless of the number of elements in said array, `respond_with` will return that content wrapped in an array, as above.

* If you pass a single object to `respond_with`, data will be presented as a single hash, as below:

  ```ruby
  respond_with User.first
  ```
  ```json
  {
    "data": {
      "id": 1,
      "name": "Mike",
      "last_name": "Sea"
    }
  }
  ```
* If you pass a boolean value, a string, or nil, the output will still contain the `data` key, but the value will only be the literal that you passed:

  ```ruby
  respond_with true # or false, or nil, or 'toast'....
  ```
  ```json
  {
    "data": true
  }
  ```
* If you pass a hash, you *must* surround your hash with parenthesis.  `respond_with` will intentionally not serialize any values of a hash.  Once again, `respond_with` WILL INTENTIONALLY NOT SERIALIZE ANY VALUES OF A HASH.  If you wish to serialize something, serialize it yourself with the `serialize` helper method:

  ```ruby
  respond_with({
    bool: true,
    user_id: 1,
    user: serialize(User.first),
    followers: serialize(User.first.followers)
  })
  ```
  ```json
  {
    "data": {
      "bool": true,
      "user_id": 1,
      "user": {
        "id": 1,
        "name": "Mike",
        "last_name": "Sea"
      },
      "followers": [
        {
          "id": 1,
          "follower_id": 100,
        },
        {
          "id": 2,
          "follower_id": 101,
        },
      ]
    }
  }
  ```
* If there are errors in the execution of the endpoint, `respond_with` will return a JSON hash with an "errors" key, along with the associated errors.

  ```ruby
  @user = User.find(9999999999)
  respond_with @user
  ```
  ```json
  {
    "errors": "Not found."
  }
  ```

### Changing response status code

`respond_with` also accepts an optional `status` option, as a second parameter.  The `status` option will specify the status code that the response should return.

```ruby
@user = User.create!(...)
respond_with @user, status: 201 # Or any other valid status code
```

### Top level elements

`respond_with` also accepts an optional `elements` option, as a second parameter.  `elements` will let you specify top-level keys for the JSON output.  The value should be a hash.

```ruby
respond_with User.first, elements: { status: 'success' }
```
```json
{
  "data": {
    "id": 1,
    "name": "Mike",
    "last_name": "Sea"
  },
  "status": "success"
}
```

Both `elements` and `status` may be combined.

## `respond_with` second parameter options

Here are all of the available second parameter options to `respond_with`.  All are optional and may be used in tandem:

- `status` will change the status of the response.  This must be a valid status code.

  ```ruby
  respond_with @user, status: 201
  ```

- `associations` must be an array and will automatically include the specified associations in the response.

  ```ruby
  respond_with @user, associations: [:profile]
  ```

- `extra_fields` must be an array and will automatically include the specified optional fields in the response.

  ```ruby
  respond_with @user, extra_fields: [:town, :favorite_color]
  ```

- `only` must be an array and will return *only* the specified fields.

  ```ruby
  respond_with @user, only: [:id, :name]
  ```

- `exclude` must be an array and will *exclude* the specified fields from the request.

  ```ruby
  respond_with @user, exclude: [:last_name]
  ```

- `elements` allows you to set root-level keys and their values.  These will *not* fall under the `data` key.

  ```ruby
  respond_with @user, elementes: { status: 'success' }
  ```

All of the above may be combined, mixed and matched, or not used at all.

## Serializers

The Quirky API gem exposes a slightly altered instance of ActiveModel Serializers.  AMS serializes an object and returns only what you want to return.

Serializers should be placed in the `app/serializers` directory, and be named `model_name_serializer.rb` where `model_name` is `object.class.underscore`.  Serializers should have this structure:

```ruby
class ModelNameSerializer < QuirkySerializer
  attributes :id, :name, :last_name, :fav_animal
  optional :town, :age
  associations :profile, :avatar

  def fav_animal
    # This overrides the value of object.fav_animal and always returns 'Giraffe'.
    'Giraffe'
  end

  def age
    # Use object to reference the model.
    if object.age > 20 && object.age < 50
      'Young'
    elsif object.age > 50
      'Old'
    else
      'Really young'
    end
  end
end
```

### Attributes

```ruby
attributes :id, :name, :last_name
```

This will specify what attributes will appear by default when serializing content with this serializer.  The value of an attribute is determined like so:

1. If the serializer has a method of the same name as an attribute, the serializer will return the value of that method.

   ```ruby
   # UserSerializer
   attribute :id, :name, :fav_animal

   # ...

   def fav_animal
     'Zebra'
   end

   # The serialized value will always be 'Zebra'.
   ```
2. If the serializer does not have a method / association of the same name as an attribute, but the model does, the serializer will return the value of the method called on the model.

   ```ruby
   # UserSerializer
   attribute :id, :name, :fav_animal

   # User model

   def fav_animal
     if real_life?
       'Giraffe'
     else
       'Taun Taun'
     end
   end

   # The serialized value of fav_animal will be either 'Giraffe' or 'Taun Taun', depending on the value of real_life?
   ```

3. If neither the serializer nor the model have a method / association of the same name as an attribute, a `NameError` will be thrown.

By default, attributes are not serialized.  If you want an attribute serialized, use the `serialize` helper method or make that attribute an association.

### Optional fields

```ruby
optional :town, :age
```

The only difference between optional fields and attributes is that optional fields do not show up by default.  Optional fields need to be requested either in the request itself, or on the endpoint with `respond_with`:

```
GET api/v1/users?extra_fields=town,age
```

Or...

```ruby
respond_with User.all, extra_fields: [:town, :age]
```

Everything else about optional fields behaves like attributes.  Optional fields are not serialized by default.  If you wish to serialize an optional field, use the `serialize` helper method or make that optional field an association.

### Associations

```ruby
associations :profile, :avatar
```

Associations are similar to attributes, but they *are* serialized based on the class of the associated object.

Retrieving the associated object on an object behaves much the same way as an attribute:

1. Check the serializer
2. Check the model
3. Fail

Once the serializer has the associated object, it attempts to find a serializer for that object and serialize it.  The value of the attribute in the original response, then, will be the serialized sub-object.

As an example, say we were serializing a User object.  The UserSerializer looks like this:

```ruby
class UserSerializer
  attributes :id, :first, :last
  associations :profile
end
```

We retrieve the profile from the user model by calling `user.profile`.  Since the profile, in turn, is an instance of the `Profile` class, it will be serialized with the `ProfileSerializer`:

```ruby
class ProfileSerializer
  attributes :bio, :town, :skills
end
```

So the complete response will look like this:

```json
{
  "data": {
    "id": 1,
    "first": "Test",
    "last": "User",
    "profile": {
      "bio": "I'm a test user",
      "town": "NYC",
      "skills": "Testing, Driving"
    }
  }
}
```

Associations do not show up by default.  They need to be requested either in the request itself, or on the endpoint with `respond_with`:

```
GET api/v1/users?associations=profile,avatar
```

Or...

```ruby
respond_with User.all, associations: [:profile, :avatar]
```

### Association filtering

Meta-filtering is possible, only for associations, due to the fact that they are serialized inside of a serialized object.  In the same way that you would request field inclusion or exclusion, optional fields and / or associations, you may do so on associations themself, by prefixing the association name to `_fields`, `_extra_fields` or `_associations`.

```ruby
respond_with User.all, associations: [:profile], profile_fields: [:town, :bio], profile_associations: [:avatar]
```

## Caching data

Caching is a very complicated topic in serialization, given serialized data often changes.  That said, there is a helper on every serializer called `caches` that attemps to aleviate some of that pain.

`caches` works by rendering an object, and along the way caching every single attribute on that object (instead of the entire object at once).  This makes processing significantly faster on subsequent serialization.  The caching works like this:

```ruby
Rails.cache.fetch [object.cache_key, field] do
  get_value(field)
end
```

This in turns uses the object's `cache_key` in order to generate the cache token.  Unless overridden, a typical cache key is `object_class_name-object_id/updated_at.to_i`.  Therefore, but touching the object at an time, you effectively bust the cache for that serialized object.

`caches` takes a number of possible values, which may be used together or not at all:

- `:all` will cache every attribute, optional field and association.
- `:fields` will cache only attributes.
- `:optional_fields` will cache only optional fields.
- `:associations` will cache only associations.
- `:field_name` will cache just that field.

Example uses:

```ruby
# Caches everything
caches :all

# Caches only fields and associations
caches :fields, :associations

# Caches the 'email' field and the 'profile' association, but nothing else
caches :email, :profile
```

## Serializing data

Data is serialized for response by way of the serializers described above.  By default, `respond_with` performs the serialization for you, but in the case that you want to serialize an object yourself, you still can.

### `serialize` helper method

The `serialize` helper method makes it easy to serialize any object or array of objects.  Simple call `serialize(object)`:

```ruby
serialize(User.first)
```

`serialize` also accepts two optional parameters:

1. the optional second parameter is the serializer to use to serialize that object.  If it is nil, the method will figure out the serializer for you.
2. the optional third parameter is any options to pass to the serializer.  You may use any of the [second parameter options for `respond_with`](#respond_with-second-parameter-options), in this parameter.

The `serialize` method also automatically sends `current_user` and `params` to every serializer, so that those values may be used inside the serializer.  You do not need to do anything for those helpers to be sent.

Examples:

```ruby
# Serializes the first user with UserSerializer
serialize(User.first)

# Serializes the first user with SpecialUserSerializer
serialize(User.first, SpecialUserSerializer)

# Serializes the first user and asks only for their first name and their profile
serialize(User.first, nil, only: [:first_name], associations: [:profile])
```

### Manual serialization

Say you wanted to serialize a single user:

```ruby
@user = UserSerializer.new(User.first).as_json(root: false)
```

Notice that we use `as_json` to return a Ruby hash of the serialized data.  You may also use `to_json` to return a JSON string.

Individual serializers also accept optional second parameters in exactly the same way that `respond_with` does.  This will allow you to request associations or optional fields, or even ask for specific fields.

```ruby
@user = UserSerializer.new(User.first, associations: [:profile], extra_fields: [:town]).as_json(root: false)
```

If you wish to ask for only specific fields, use the `only` parameter:

```ruby
@user = UserSerializer.new(User.first, only: [:id, :name]).as_json(root: false)
```

### Array serialization

If you wish to serialize an array of objects, use `QuirkyArraySerializer`.

```ruby
@user = QuirkyArraySerializer.new(User.all).as_json(root: false)
```

The same options that apply to object serialization apply to `QuirkyArraySerializer`.  `QuirkyArraySerializer` will attempt to find a serializer for every item in the array, and serialize that item with that serializer and with any options passed as the second parameter.

```ruby
@user = QuirkyArraySerializer.new(User.all, only: [:id, :name]).as_json(root: false)
```

# QuirkyApi::Response::Pagination

## Explanation

The `QuirkyApi::Response::Pagination` is a library that provides various pagination utilities to paginate responses.

### `paginate_with_cursor`

`paginate_with_cursor` paginates the collection or array sent as a parameter and provides the paginated objects, next_cursor and prev_cursor.

Parameters:
- Objects (Array or collection of objects that need to be paginated)
- Options (hash): A hash of options that will overwrite `cursor_pagination_options`. Possible options are:
  * `per_page`: number of items required per page. Defaults to 10.
  * `cursor`: the starting cursor from which to get records. Can be null.
  * `reverse`: boolean indicating whether the objects are sent in reverse order or not so the correct objects can be displayed next. Defaults to false.
  * `ambiguous_field`: This is used to indicate what field needs to be used for the querying. This is *required* in the case the queried collection has been joined with other tables. It is usually the `id` field of the primary table. E.g.: 'users.id'
  * `field`: this is the field that the ordering / comparison needs to be done on the basis of. `date` and `id` are currently supported. Defaults to `id`.

Returns a 3-tuple of `(paginated_objects, next_cursor, prev_cursor)`:
- `paginated_objects`: The object limited by `per_page` based on the `cursor` provided
- `next_cursor`: The cursor indicating the starting point of the next page (if one exists). Send it back to the request if you want to get the next page.
- `prev_cursor`: The cursor indicuting the staarting point of the previous page (if one exists). Send it back to the request if you want to get the previous page.

### `cursor_pagination_headers`

This method sets Hypermedia-style link headers for a collection of cursor-based paginated objects. See [Github Pagination](https://developer.github.com/guides/traversing-with-pagination/#basics-of-pagination)

Parameters:
- Objects: The unscoped object(s) to paginate. Do not pass the same set of objects returned by +paginate_with_cursor+, the total will not be calculated correctly using those.
- Next Cursor: The next_cursor returned by `paginate_with_cursor`.
- Previous Cursor: The prev_cursor returned by `paginate_with_cursor`.
- Options (hash): A hash of options that will overwrite `cursor_pagination_options`.
  * `url`: An array of URL options that will be passed to [polymorphic_url](http://api.rubyonrails.org/classes/ActionDispatch/Routing/PolymorphicRoutes.html#method-i-polymorphic_url polymorphic_url).

Returns:
- Response Headers with the Link Attribute: E.g. Link: <https://quirky.com/api/v1/users?per_page=5&cursor=3847>; rel="next",
  <https://quirky.com/api/v1/users?per_page=5&cursor=1007>; rel="prev"
