# adapted from https://github.com/intridea/omniauth#getting-started
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer unless Rails.env.production?
  #provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
end
OmniAuth.config.logger = Rails.logger
