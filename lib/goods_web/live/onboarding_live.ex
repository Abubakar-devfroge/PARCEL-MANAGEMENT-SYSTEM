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

    form = ensure_form_tenant(socket.assigns.form, socket.assigns.current_user, params)

    form =
      AshPhoenix.Form.validate(form, params,
        errors: false,
        only_touched?: true,
        target: target
      )

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"business_profile" => params}, socket) do
    normalized_params = normalize_routing_params(params)
    form = ensure_form_tenant(socket.assigns.form, socket.assigns.current_user, normalized_params)

    case AshPhoenix.Form.submit(form, params: normalized_params) do
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
    form = build_create_form(socket.assigns.current_user, %{})

    assign(socket, :form, to_form(form))
  end

  defp assign_form(socket, profile) do
    form = build_update_form(profile, socket.assigns.current_user)

    assign(socket, :form, to_form(form))
  end

  defp get_business_profile(current_user) do
    case current_company_tenant(current_user) do
      nil ->
        nil

      tenant ->
        Goods.Accounts.BusinessProfile
        |> Ash.Query.filter(user_id == ^current_user.id)
        |> Ash.read_one!(actor: current_user, tenant: tenant)
    end
  end

  defp ensure_form_tenant(form, current_user, params) do
    tenant = derived_company_tenant(current_user, params)
    current_tenant = form.source.opts[:tenant]

    cond do
      form.source.type != :create ->
        form

      tenant == current_tenant ->
        form

      true ->
        build_create_form(current_user, params)
        |> to_form()
    end
  end

  defp build_create_form(current_user, params) do
    opts = [as: "business_profile", actor: current_user]

    case derived_company_tenant(current_user, params) do
      nil ->
        AshPhoenix.Form.for_create(Goods.Accounts.BusinessProfile, :create, opts)

      tenant ->
        AshPhoenix.Form.for_create(
          Goods.Accounts.BusinessProfile,
          :create,
          opts ++ [tenant: tenant]
        )
    end
  end

  defp build_update_form(profile, current_user) do
    opts = [as: "business_profile", actor: current_user]

    case current_company_tenant(current_user) || normalize_company_key(profile.company_key) do
      nil -> AshPhoenix.Form.for_update(profile, :update, opts)
      tenant -> AshPhoenix.Form.for_update(profile, :update, opts ++ [tenant: tenant])
    end
  end

  defp derived_company_tenant(current_user, params) do
    current_company_tenant(current_user) || normalize_company_key(Map.get(params, "company_name"))
  end

  defp current_company_tenant(nil), do: nil

  defp current_company_tenant(current_user) do
    normalize_company_key(current_user.company_key)
  end

  defp normalize_company_key(nil), do: nil

  defp normalize_company_key(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      normalized -> normalized
    end
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
