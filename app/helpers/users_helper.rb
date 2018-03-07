module UsersHelper

  def delete_account(user)

    UnsubscribeUserFromMailChimp.perform_later(user.email)

    cronofy = cronofy_client(user)

    cronofy.revoke_authorization

    user.destroy!

    log.info { "#delete_account for user_id=#{user.id} completed" }
  rescue => e
    log.error "#delete_account failed for user_id=#{user.id} - #{e.class} - #{e.message}", e
    raise
  end

private

  def cronofy_client(user)
    @cronofy_client ||= Cronofy::Client.new(
      access_token: user.cronofy_access_token,
      refresh_token: user.cronofy_refresh_token,
    )
  end

end
