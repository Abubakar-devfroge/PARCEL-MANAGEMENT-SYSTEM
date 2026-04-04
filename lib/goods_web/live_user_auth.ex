defmodule GoodsWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews and managing session persistence.
  """

  import Phoenix.Component
  use GoodsWeb, :verified_routes

  require Ash.Query
  alias AshAuthentication.Phoenix.LiveSession, as: AuthLive

  #
  # On mount helpers
  #

  # Assign current user from session
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AuthLive.assign_new_resources(socket, session)}
  end

  # Optional user: assigns current_user if present, else nil
  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  # Require logged-in user
  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      current_user = socket.assigns.current_user
      onboarding_complete = onboarding_complete?(current_user)

      cond do
        socket.view == GoodsWeb.OnboardingLive and onboarding_complete ->
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/dash")}

        socket.view == GoodsWeb.OnboardingLive and not onboarding_complete ->
          {:cont, socket}

        onboarding_complete ->
          {:cont, socket}

        true ->
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/onboarding")}
      end
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Admin-only access
  def on_mount(:live_admin_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      current_user = socket.assigns.current_user
      onboarding_complete = onboarding_complete?(current_user)

      cond do
        not onboarding_complete ->
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/onboarding")}

        admin?(current_user) ->
          {:cont, socket}

        true ->
          {:halt,
           socket
           |> Phoenix.LiveView.put_flash(:error, "Only managers can access reports")
           |> Phoenix.LiveView.redirect(to: ~p"/dash")}
      end
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Ensure user is logged out
  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  #
  # Private helpers
  #

  defp onboarding_complete?(current_user) do
    case normalize_company_key(current_user.company_key) do
      nil ->
        false

      tenant ->
        Goods.Accounts.BusinessProfile
        |> Ash.Query.filter(user_id == ^current_user.id)
        |> Ash.exists?(actor: current_user, tenant: tenant)
    end
  end

  defp normalize_company_key(nil), do: nil

  defp normalize_company_key(company_key) do
    company_key
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false
end
