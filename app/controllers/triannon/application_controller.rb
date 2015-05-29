module Triannon
  class ApplicationController < ActionController::Base
      helper_method :current_user, :logged_in?
      private
      def current_user
        # triannon has no User db (as yet), details are in the session.
        # @current_user ||= User.find(session[:user_id]) if session[:user_id]
        @current_user ||= session[:current_user] if session[:current_user]
      end
      def current_user=(user)
          session[:current_user] = user
          @current_user = user
      end
      def logged_in?
          !!current_user
      end
  end
end
