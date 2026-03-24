defmodule GoodsWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use GoodsWeb, :verified_routes

  require Ash.Query

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {GoodsWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      onboarding_complete = onboarding_complete?(socket.assigns.current_user)

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

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp onboarding_complete?(current_user) do
    Goods.Accounts.BusinessProfile
    |> Ash.Query.filter(user_id == ^current_user.id)
    |> Ash.exists?(actor: current_user)
  end
end
