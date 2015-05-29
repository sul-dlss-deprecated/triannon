# adapted from https://github.com/intridea/omniauth#getting-started
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer unless Rails.env.production?
  # The :developer provides has useful default fields that could be
  # overridden, but a better implementation must use an alternative provider.
  #provider :identity, :fields => [:name, :email]
  #provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
end
OmniAuth.config.logger = Rails.logger
