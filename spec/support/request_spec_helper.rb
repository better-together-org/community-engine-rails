module RequestSpecHelper
  def json
    JSON.parse(response.body)
  end

  def login(user)
    post better_together.user_session_path, params: {
      user: { email: user.email, password: user.password }
    }
  end
end
