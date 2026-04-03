defmodule GoodsWeb.SetPasswordLive do
  use GoodsWeb, :live_view

  alias Goods.Accounts.Employees
  alias Goods.Accounts.InviteTokens

  @impl true
  def mount(params, _session, socket) do
    token = params["token"]

    {status, invitee_email} = token_status(token)

    {:ok,
     socket
     |> assign(:page_title, "Set Password")
     |> assign(:token, token)
     |> assign(:token_status, status)
     |> assign(:invitee_email, invitee_email)
     |> assign(:password_form, password_form())}
  end

  @impl true
  def handle_event("validate", %{"password" => params}, socket) do
    {:noreply, assign(socket, :password_form, password_form(params))}
  end

  @impl true
  def handle_event("save", %{"password" => params}, socket) do
    password = Map.get(params, "password", "")
    password_confirmation = Map.get(params, "password_confirmation", "")

    case Employees.set_password_from_invite(socket.assigns.token, password, password_confirmation) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Password set successfully. You can now sign in.")
         |> push_navigate(to: ~p"/sign-in")}

      {:error, :expired_token} ->
        {:noreply,
         socket
         |> assign(:token_status, :expired)
         |> put_flash(:error, "This invite link has expired")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not set password. Check the token and try again")
         |> assign(:password_form, password_form(params))}
    end
  end

  defp token_status(nil), do: {:missing, nil}
  defp token_status(""), do: {:missing, nil}

  defp token_status(token) do
    case Employees.find_user_by_invite_token(token) do
      {:ok, user} ->
        if InviteTokens.expired?(user.invite_sent_at) do
          {:expired, user.email}
        else
          {:valid, user.email}
        end

      {:error, _reason} ->
        {:invalid, nil}
    end
  end

  defp password_form(params \\ %{}) do
    defaults = %{"password" => "", "password_confirmation" => ""}
    to_form(Map.merge(defaults, params), as: "password")
  end
end
