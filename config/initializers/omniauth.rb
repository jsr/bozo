require 'openid/store/filesystem'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid, OpenID::Store::Filesystem.new('/tmp'), :name => '10gen',
           :identifier => 'https://www.google.com/accounts/o8/site-xrds?hd=10gen.com'

#  provider :openid, OpenID::Store::Filesystem.new('/tmp'), :name => 'google',
#           :identifier => 'https://www.google.com/accounts/o8/id'

  provider :openid, OpenID::Store::Filesystem.new('/tmp'), :name => 'yahoo',
           :identifier => 'https://me.yahoo.com'

#  provider :twitter, 'CONSUMER_KEY', 'CONSUMER_SECRET'
#  provider :facebook, 'APP_ID', 'APP_SECRET'
#  provider :linked_in, 'CONSUMER_KEY', 'CONSUMER_SECRET'
end