module EvernoteOAuth
  class Client
    # Make the private method "endpoint" public so we can use it to generate
    # environment-matching note URLs.
    public :endpoint
  end
end
