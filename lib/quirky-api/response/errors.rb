module QuirkyApi
  module Response
    module Errors
      # Returns a 400 bad request response.
      def bad_request(e)
        error_response(e, 400)
      end

      def respond_bad_request(errors)
        error_response(errors)
      end

      alias_method :param_invalid, :respond_bad_request

      def respond_bad_request_with_errors(errors)
        errors = translate_errors(errors)
        respond_bad_request(errors)
      end

      def record_invalid(e)
        respond_bad_request_with_errors(e.record.errors)
      end

      # Returns a 401 unauthorized response.
      def unauthorized(e)
        error_response('You are not authorized to do that.', 401)
      end

      def respond_unauthorized(message = nil)
        if message
          error_response(message, 401)
        else
          head :unauthorized
        end
        @performed_render = true
      end

      # Returns 403 (Forbidden) response.
      def forbidden(e)
        error_response('You are forbidden to do that.', 403)
      end

      def respond_forbidden
        head :forbidden
        @performed_render = true
      end

      # Returns a 404 not found response.
      def not_found(e)
        error_response('Not found.', 404)
      end

      def respond_not_found
        head :not_found
        @performed_render = true
      end

      alias_method :unknown_action, :respond_not_found

      # Returns 409 (conflict) for not unique records.
      def not_unique(e)
        error_response('Record not unique.', 409)
      end

      alias_method :conflict, :not_unique

      # Returns 500 (Internal Server Error).
      def internal_error(e)
        if QuirkyApi.exception_handler
          QuirkyApi.exception_handler.call(e)
        else
          # Rails.logger.error e.message
        end

        error_response('Something went wrong.')
      end

      def validate_multiple(objects)
        objects.each_with_object({}) do |obj, errors|
          if obj.invalid?
            matched = obj.to_s.match(/([A-Za-z0-9\-\_]*)\:([A-Za-z0-9\-\_]*)/)
            klass, oid = matched[1], matched[2]

            errors["#{klass}:#{oid}"] = translate_errors(obj.errors)
          end
        end
      end

      def translate_errors(errors)
        # Gets the model that has the errors.
        model = errors.instance_variable_get('@base')

        errors.each_with_object({}) do |(key, error), hsh|
          # Some nested attributes get a weird dot syntax.
          key = key.to_s.split('.').last if key.match(/\./)

          # Retrieves the full error and cleans it as necessary.
          full_message = if key.to_s == 'base'
                           error
                         else
                           col = model.class.human_attribute_name(key)
                           "#{col} #{error}"
                         end

          (hsh[key] ||= []) << full_message
        end
      end

      private

      # Returns an error with a status code.
      #
      # @param msg [String] The message to show up.
      # @param status [Fixnum] The status code to return.  Default is 400.
      def error_response(msg, status = 400)
        render json: { errors: msg }, status: status
      end
    end
  end
end
