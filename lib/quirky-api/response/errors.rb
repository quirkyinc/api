module QuirkyApi
  module Response
    module Errors
      # Returns a 400 bad request response.
      #
      # @param e [String] A string that describes the errors that happened.
      #
      def bad_request(e)
        error_response(e, 400)
      end

      # Returns a 400 bad request response.
      #
      # @param errors [String] A string that describes the errors that happened.
      #
      def respond_bad_request(errors)
        error_response(errors)
      end

      alias_method :param_invalid, :respond_bad_request

      # Returns a 400 bad request, and maps out individual errors based on
      # problematic fields.
      #
      # @param errors [Object] An object of errors that will be 'translated'
      #                        through +translate_errors+.
      #
      def respond_bad_request_with_errors(errors)
        errors = translate_errors(errors)
        respond_bad_request(errors)
      end

      # Returns a 400 bad request, and maps out individual errors based on
      # problematic fields.
      #
      # @param e [Object] An object that hs errors on it.
      #
      # @see respond_bad_request_with_errors
      #
      def record_invalid(e)
        respond_bad_request_with_errors(e.record.errors)
      end

      # Returns a 401 unauthorized response.
      #
      # @param e [Exception] The exception that was raised.
      #
      def unauthorized(e)
        error_response('You are not authorized to do that.', 401)
      end

      # Returns 401 (Unauthorized).  If +message+ is blank, will return an
      # +Unauthorized+ header instead of outputting anything.
      #
      # @param message [String] If applicable, a message describing the problem.
      #
      def respond_unauthorized(message = nil)
        if message
          error_response(message, 401)
        else
          head :unauthorized
        end
        @performed_render = true
      end

      # Returns 403 (Forbidden) response.
      #
      # @param e [Exception] The exception object.
      #
      def forbidden(e)
        error_response('You are forbidden to do that.', 403)
      end

      # Returns 403 (Forbidden) header.
      #
      def respond_forbidden
        head :forbidden
        @performed_render = true
      end

      # Returns a 404 not found response.
      #
      def not_found(e)
        error_response('Not found.', 404)
      end

      # Returns 404 (Not Found) header.
      #
      def respond_not_found
        head :not_found
        @performed_render = true
      end

      alias_method :unknown_action, :respond_not_found

      # Returns 409 (conflict) for not unique records.
      #
      # @param e [Exception] The exception that was raised.
      #
      def not_unique(e)
        error_response('Record not unique.', 409)
      end

      alias_method :conflict, :not_unique

      # Returns 500 (Internal Server Error).
      #
      # @param e [Exception] The exception that was raised.
      #
      def internal_error(e)
        if QuirkyApi.exception_handler
          QuirkyApi.exception_handler.call(e)
        else
          Rails.logger.error e.message
        end

        error_response('Something went wrong.')
      end

      # Validates multiple objects and returns their errors as a hash.  The key
      # of each element will be "#{class_name}:#{object_id}".  The value will
      # be the result of +translate_errors+.
      #
      # @param objects [Array] An array of objects to validate.
      #
      # @return [Hash] A hash of objects and their errors, if applicable.
      #
      def validate_multiple(objects)
        objects.each_with_object({}) do |obj, errors|
          if obj.invalid?
            matched = obj.to_s.match(/([A-Za-z0-9\-\_]*)\:([A-Za-z0-9\-\_]*)/)
            klass, oid = matched[1], matched[2]

            errors["#{klass}:#{oid}"] = translate_errors(obj.errors)
          end
        end
      end

      # Retrieves all errors on an object and maps each error to the specific
      # problematic field.
      #
      # @param errors [Object] An errors object that will be 'translated'.
      #
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

      # Returns an error with a status code.
      #
      # @param msg [String] The message to show up.
      # @param status [Fixnum] The status code to return.  Default is 400.
      #
      def error_response(msg, status = 400)
        render json: { errors: msg }, status: status
      end

      # Return an error with a status code.
      #
      # @param e [Exception] A raised exception.
      # @param status [Fixnum] A valid status code.
      #
      # @see error_response
      #
      def error(e, status = 400)
        error_response(e.message, status)
      end
    end
  end
end
