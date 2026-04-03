defmodule Goods.Accounts.EmployeeInviteMailer do
  @moduledoc """
  Sends employee onboarding invites through Resend.
  """

  @resend_url "https://api.resend.com/emails"

  def deliver_invite_email(user, raw_token) do
    with {:ok, api_key} <- fetch_config(:resend_api_key),
         {:ok, from_email} <- fetch_config(:resend_from_email),
         {:ok, base_url} <- fetch_config(:app_base_url),
         {:ok, _response} <- post_invite(api_key, from_email, base_url, user, raw_token) do
      :ok
    end
  end

  defp post_invite(api_key, from_email, base_url, user, raw_token) do
    invite_url =
      "#{String.trim_trailing(base_url, "/")}/set-password?token=#{URI.encode_www_form(raw_token)}"

    payload = %{
      from: from_email,
      to: [to_string(user.email)],
      subject: "You have been invited to BUSCAR",
      html: html_body(user, invite_url),
      text: text_body(user, invite_url)
    }

    case Req.post(
           url: @resend_url,
           headers: [{"authorization", "Bearer #{api_key}"}],
           json: payload
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, :sent}

      {:ok, %{status: status, body: body}} ->
        {:error, {:resend_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp html_body(user, invite_url) do
    name = user.name || "there"

    """
    <div style=\"font-family:Arial,sans-serif;line-height:1.5;color:#111827\">
      <h2 style=\"margin-bottom:8px\">Welcome to BUSCAR</h2>
      <p>Hello #{name},</p>
      <p>Your employee account has been created. Use the link below to set your password:</p>
      <p><a href=\"#{invite_url}\">Set your password</a></p>
      <p>This invite link expires in 7 days.</p>
      <p>If you did not expect this email, you can ignore it.</p>
    </div>
    """
  end

  defp text_body(user, invite_url) do
    name = user.name || "there"

    """
    Welcome to BUSCAR

    Hello #{name},

    Your employee account has been created. Use this link to set your password:
    #{invite_url}

    This invite link expires in 7 days.
    If you did not expect this email, you can ignore it.
    """
  end

  defp fetch_config(key) do
    case Application.get_env(:goods, :employee_invites, []) |> Keyword.get(key) do
      nil -> {:error, {:missing_config, key}}
      "" -> {:error, {:missing_config, key}}
      value -> {:ok, value}
    end
  end
end
