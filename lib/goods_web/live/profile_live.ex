defmodule GoodsWeb.ProfileLive do
  use GoodsWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    business_profile = get_business_profile(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Profile")
     |> assign(:active_tab, "personal")
     |> assign(:business_profile, business_profile)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab =
      case params["tab"] do
        "license" -> "license"
        _ -> "personal"
      end

    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
        <div class="border border-gray-200 bg-white">
          <div class="border-b border-gray-200 px-4 py-3 sm:px-6">
            <h1 class="text-xl font-semibold text-gray-900">Profile</h1>
            <p class="mt-1 text-sm text-gray-500">Personal and license information</p>
          </div>

          <div class="border-b border-gray-200 bg-gray-50 px-4 py-2 sm:px-6">
            <div class="flex items-center gap-2">
              <.link
                patch={~p"/profile?tab=personal"}
                class={[
                  "rounded-md px-3 py-1.5 text-sm font-medium transition",
                  @active_tab == "personal" &&
                    "border border-amber-300 bg-amber-100 text-amber-900",
                  @active_tab != "personal" && "text-amber-800 hover:bg-amber-50 hover:text-amber-900"
                ]}
              >
                Personal Information
              </.link>

              <.link
                patch={~p"/profile?tab=license"}
                class={[
                  "rounded-md px-3 py-1.5 text-sm font-medium transition",
                  @active_tab == "license" &&
                    "border border-amber-300 bg-amber-100 text-amber-900",
                  @active_tab != "license" && "text-amber-800 hover:bg-amber-50 hover:text-amber-900"
                ]}
              >
                License Information
              </.link>
            </div>
          </div>

          <section :if={@active_tab == "personal"} class="px-4 py-4 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              Personal Information
            </h2>

            <div class="mt-3 overflow-x-auto border border-gray-200">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                  <tr>
                    <th class="w-1/3 bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Email Address
                    </th>
                    <td class="px-4 py-3 break-all">{@current_user.email}</td>
                  </tr>
                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Company Name
                    </th>
                    <td class="px-4 py-3 break-all">
                      {profile_value(@business_profile, :company_name)}
                    </td>
                  </tr>
                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Business Type
                    </th>
                    <td class="px-4 py-3 break-all">
                      {profile_value(@business_profile, :business_type)}
                    </td>
                  </tr>
                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Primary City / Base Location
                    </th>
                    <td class="px-4 py-3 break-all">
                      {profile_value(@business_profile, :primary_city)}
                    </td>
                  </tr>

                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Account Status
                    </th>
                    <td class="px-4 py-3">
                      <%= if @current_user.confirmed_at do %>
                        Verified
                      <% else %>
                        Pending Verification
                      <% end %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section :if={@active_tab == "license"} class="px-4 py-4 sm:px-6">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-gray-700">
              License Information
            </h2>

            <div class="mt-3 overflow-x-auto border border-gray-200">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <tbody class="divide-y divide-gray-200 bg-white text-gray-900">
                  <tr>
                    <th class="w-1/3 bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      License Number
                    </th>
                    <td class="px-4 py-3 text-gray-600">Not Available</td>
                  </tr>
                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      License Category
                    </th>
                    <td class="px-4 py-3 text-gray-600">Not Available</td>
                  </tr>
                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Issue Date
                    </th>
                    <td class="px-4 py-3 text-gray-600">Not Available</td>
                  </tr>
                  <tr>
                    <th class="bg-gray-50 px-4 py-3 text-left font-medium text-gray-700">
                      Expiry Date
                    </th>
                    <td class="px-4 py-3 text-gray-600">Not Available</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp get_business_profile(current_user) do
    Goods.Accounts.BusinessProfile
    |> Ash.Query.filter(user_id == ^current_user.id)
    |> Ash.read_one!(actor: current_user)
  end

  defp profile_value(nil, _field), do: "Not Available"

  defp profile_value(profile, field) do
    value = Map.get(profile, field)

    if is_binary(value) and String.trim(value) != "" do
      value
    else
      "Not Available"
    end
  end
end
