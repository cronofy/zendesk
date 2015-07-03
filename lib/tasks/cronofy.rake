include Hatchet

def cronofy_client(user)
  Cronofy::Client.new(
    access_token: user.cronofy_access_token,
    refresh_token: user.cronofy_refresh_token,
  )
end

# Wrapper for Cronofy API requests to handle refreshing the access token
def cronofy_request(user, &block)
  if user.cronofy_access_token_expired?(Time.now)
    log.info { "#cronofy_request pre-emptively refreshing expired token" }
    refresh_cronofy_access_token(user)
  end

  begin
    block.call
  rescue Cronofy::AuthenticationFailureError
    log.info { "#cronofy_request attempting to refresh token - user=#{user.id}" }
    refresh_cronofy_access_token(user)
    block.call
  end
rescue Cronofy::AuthenticationFailureError => e
  log.warn "#cronofy_request failed - user=#{user.id} - #{e.class} - #{e.message}", e
  raise CronofyCredentialsInvalid.new(user.id)
rescue => e
  log.error "#cronofy_request failed - user=#{user.id} - #{e.class} - #{e.message}", e
  raise
end

def refresh_cronofy_access_token(user)
  credentials = cronofy_client(user).refresh_access_token

  user.cronofy_access_token = credentials.access_token
  user.cronofy_refresh_token = credentials.refresh_token
  user.cronofy_access_token_expiration = Time.at(credentials.expires_at).getutc

  user.save
rescue Cronofy::BadRequestError => e
  log.warn "#refresh_cronofy_access_token failed - user=#{user.id} - #{e.class} - #{e.message}", e
  raise CronofyCredentialsInvalid.new(user.id)
end


namespace :cronofy do

  task :sync_cronofy_accounts => :environment do
    User.all.each do |user|
      cronofy_account = cronofy_request(user) { cronofy_client(user).account }

      user.email = cronofy_account['email']
      user.name = cronofy_account['name']
      user.save

      log.info { "cronofy:sync_cronofy_accounts synced account for user=#{user.id}" }
    end
  end

  task :sync_mail_chimp => :environment do
    User.all.each do |user|
      SyncMailChimpSubscriberWithUser.perform_later(user.id)
    end
  end
end