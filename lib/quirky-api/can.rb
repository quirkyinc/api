# encoding: utf-8
module QuirkyApi
  # Provides CanCanCan functionality.
  module Can
    def authorize!(ability, obj, *args)
      # current_user_or_guest.ability.authorize!(ability, obj, args)
    end

    def can?(action, subject, *args)
      # current_user_or_guest.ability.can?(action, subject, args)
    end

    def cannot?(action, subject, *args)
      # current_user_or_guest.ability.cannot?(action, subject, args)
    end
  end
end
