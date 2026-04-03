defmodule Goods.Accounts.InviteTokens do
  @moduledoc """
  Utilities for one-time employee invite tokens.
  """

  @invite_ttl_seconds 7 * 24 * 60 * 60

  def generate do
    raw_token =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    {raw_token, hash(raw_token), DateTime.utc_now()}
  end

  def hash(token) when is_binary(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end

  def expired?(%DateTime{} = invite_sent_at) do
    DateTime.diff(DateTime.utc_now(), invite_sent_at, :second) > @invite_ttl_seconds
  end

  def expired?(_), do: true
end
