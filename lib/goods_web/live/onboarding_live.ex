defmodule GoodsWeb.OnboardingLive do
  use GoodsWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    profile = get_business_profile(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Business Onboarding")
     |> assign(:show_cancel_warning, false)
     |> assign(:business_profile, profile)
     |> assign_form(profile)}
  end

  @impl true
  def handle_event("validate", %{"business_profile" => params} = event_params, socket) do
    target = Map.get(event_params, "_target", [])

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params,
        errors: false,
        only_touched?: true,
        target: target
      )

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"business_profile" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: normalize_routing_params(params)) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> assign(:business_profile, profile)
         |> put_flash(:info, "Onboarding completed successfully")
         |> push_navigate(to: ~p"/dash")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("cancel_onboarding", _params, socket) do
    {:noreply, assign(socket, :show_cancel_warning, true)}
  end

  @impl true
  def handle_event("continue_onboarding", _params, socket) do
    {:noreply, assign(socket, :show_cancel_warning, false)}
  end

  @impl true
  def handle_event("confirm_cancel_onboarding", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_cancel_warning, false)
     |> redirect(to: ~p"/sign-out")}
  end

  defp assign_form(socket, nil) do
    form =
      AshPhoenix.Form.for_create(Goods.Accounts.BusinessProfile, :create,
        as: "business_profile",
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  defp assign_form(socket, profile) do
    form =
      AshPhoenix.Form.for_update(profile, :update,
        as: "business_profile",
        actor: socket.assigns.current_user
      )

    assign(socket, :form, to_form(form))
  end

  defp get_business_profile(current_user) do
    Goods.Accounts.BusinessProfile
    |> Ash.Query.filter(user_id == ^current_user.id)
    |> Ash.read_one!(actor: current_user)
  end

  defp normalize_routing_params(params) do
    primary_city = Map.get(params, "primary_city", "") |> String.trim()
    base_office = Map.get(params, "base_office", "") |> String.trim()

    if base_office == "" and primary_city != "" do
      Map.put(params, "base_office", primary_city)
    else
      params
    end
  end
end
