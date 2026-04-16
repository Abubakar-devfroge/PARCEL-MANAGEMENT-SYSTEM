defmodule GoodsWeb.Navigation do
  @moduledoc """
  Reusable UI components for application navigation.
  """
  use GoodsWeb, :html
  attr :current_user, :map, default: nil
  slot :inner_content

  def navbar(assigns) do
    ~H"""
    <%= if @current_user do %>
      <div class="min-h-screen bg-gray-100 flex flex-col">
        
    <!-- Top Navbar -->
        <header class="w-full bg-white border-b border-gray-200">
          <nav class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex h-16 items-center justify-between">
              
    <!-- LEFT: BRAND -->
              <.link navigate={~p"/dash"} class="flex items-center gap-4">
                <img src={~p"/images/logo1.svg"} class="h-10 w-auto" />
              </.link>
              
    <!-- RIGHT: USER + ACTIONS -->
              <div class="flex items-center gap-3">
                
    <!-- SETTINGS -->
                <div class="relative hidden sm:block">
                  <button
                    phx-click={JS.toggle(to: "#settings-menu")}
                    class="p-2 rounded-full border border-gray-300 hover:bg-gray-100"
                  >
                    <.icon name="hero-cog-6-tooth" class="h-5 w-5 text-gray-600" />
                  </button>

                  <div
                    id="settings-menu"
                    class="hidden absolute right-0 mt-2 w-56 bg-white border border-gray-200 rounded-lg shadow-lg"
                  >
                    <div class="p-3 space-y-2">
                      <button class="w-full text-left text-sm text-gray-700 hover:bg-gray-100 px-3 py-2 rounded">
                        Dark Mode
                      </button>

                      <button class="w-full text-left text-sm text-gray-700 hover:bg-gray-100 px-3 py-2 rounded">
                        Preferences
                      </button>
                    </div>
                  </div>
                </div>
                
    <!-- USER DROPDOWN -->
                <div class="relative">
                  <button
                    phx-click={JS.toggle(to: "#user-menu")}
                    class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-gray-300 hover:bg-gray-100"
                  >
                    <span class="text-sm text-gray-700">
                      {@current_user.email}
                    </span>

                    <svg class="h-4 w-4 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z" />
                    </svg>
                  </button>
                  
    <!-- DROPDOWN -->
                  <div
                    id="user-menu"
                    class="hidden absolute right-0 mt-2 w-56 bg-white border border-gray-200 rounded-lg shadow-lg"
                  >
                    <div class="py-1">
                      <.link
                        navigate={~p"/profile"}
                        class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      >
                        Profile
                      </.link>

                      <.link
                        navigate={~p"/profile"}
                        class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      >
                        Settings
                      </.link>

                      <div class="border-t border-gray-100"></div>

                      <.link
                        href={~p"/sign-out"}
                        class="block px-4 py-2 text-sm text-red-600 hover:bg-gray-100"
                      >
                        Log out
                      </.link>
                    </div>
                  </div>
                </div>
                
    <!-- MOBILE MENU BUTTON -->
                <button
                  class="md:hidden p-2 rounded-md border border-gray-300"
                  phx-click={JS.toggle(to: "#mobile-menu")}
                >
                  <.icon name="hero-bars-3" class="h-5 w-5" />
                </button>
              </div>
            </div>
          </nav>
          
    <!-- MOBILE MENU -->
          <div id="mobile-menu" class="hidden md:hidden border-t border-gray-200 bg-white">
            <div class="px-4 py-3 space-y-2">
              <.link navigate={~p"/dash"} class="block text-sm text-gray-700 hover:text-black">
                Dashboard
              </.link>

              <.link
                navigate={~p"/parcel_bookings"}
                class="block text-sm text-gray-700 hover:text-black"
              >
                Parcels
              </.link>

              <.link navigate={~p"/employees"} class="block text-sm text-gray-700 hover:text-black">
                Employees
              </.link>

              <.link
                navigate={~p"/parcel_reports"}
                class="block text-sm text-gray-700 hover:text-black"
              >
                Reports
              </.link>

              <div class="border-t pt-2 mt-2">
                <.link href={~p"/sign-out"} class="block text-sm text-red-600">
                  Log out
                </.link>
              </div>
            </div>
          </div>
        </header>
        
    <!-- PAGE BODY -->
        <main class="flex-1 ">
          <div class="mx-auto max-w-7xl px-4 sm:px-4 lg:px-4 py-4">
            
    <!-- GRID -->
            <div class="grid grid-cols-1 lg:grid-cols-12 gap-4 items-stretch">
              
    <!-- LEFT CARD (THINNER + TALLER FEEL) -->
              <aside class="lg:col-span-3">
                <div class="p-4 mt-2 sm:p-6 bg-white ring-1 ring-gray-100 min-h-full rounded-2xl ring-dark">
                  <!-- Header -->
                  <div class="mt-4">
                    <form phx-change="search" phx-submit="search">
                      <label for="search" class="sr-only">Search Country</label>
                      <div class="grid grid-cols-1">
                        <svg
                          class="pointer-events-none col-start-1 row-start-1 ml-3 size-5 self-center text-gray-500 z-10"
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 20 20"
                        >
                          <path
                            fill="currentColor"
                            d="M9.25 2.5A6.752 6.752 0 0 1 16 9.25 6.752 6.752 0 0 1 9.25 16 6.752 6.752 0 0 1 2.5 9.25 6.752 6.752 0 0 1 9.25 2.5Zm0 12c2.9 0 5.25-2.35 5.25-5.25C14.5 6.349 12.15 4 9.25 4A5.248 5.248 0 0 0 4 9.25c0 2.9 2.349 5.25 5.25 5.25Zm6.364.053 2.121 2.121-1.06 1.061-2.122-2.121 1.06-1.06Z"
                          >
                          </path>
                        </svg>
                        <input
                          type="search"
                          id="search"
                          name="search"
                          placeholder="Search "
                          autocomplete="off"
                          class="col-start-1 row-start-1 block w-full rounded-md bg-transparent border border-gray-100 focus:border focus:border-blue-700 py-1.5 pl-10 pr-3 user_dialog_input"
                        />
                      </div>
                    </form>
                  </div>
                  
    <!-- Nav -->
                  <div class="p-3 space-y-1 flex-1">
                    <.link
                      navigate={~p"/dash"}
                      class="block px-4 py-2.5 rounded-lg hover:bg-gray-100 text-sm font-medium text-gray-700"
                    >
                      <.icon
                        name="hero-home"
                        class="h-6 w-6 text-black transition-colors group-hover:text-black"
                      /> Dashboard
                    </.link>

                    <.link
                      navigate={~p"/parcel_bookings"}
                      class="block px-4 py-2.5 rounded-lg hover:bg-gray-100 text-sm font-medium text-gray-700"
                    >
                      <.icon
                        name="hero-cube-transparent"
                        class="h-6 w-6 text-black transition-colors group-hover:text-black"
                      /> Parcels
                    </.link>

                    <.link
                      navigate={~p"/employees"}
                      class="block px-4 py-2.5 rounded-lg hover:bg-gray-100 text-sm font-medium text-gray-700"
                    >
                      <.icon
                        name="hero-users"
                        class="h-6 w-6 text-black transition-colors group-hover:text-black"
                      /> Employees Management
                    </.link>

                    <.link
                      navigate={~p"/parcel_reports"}
                      class="block px-4 py-2.5 rounded-lg hover:bg-gray-100 text-sm font-medium text-gray-700"
                    >
                      <.icon
                        name="hero-chart-bar"
                        class="h-6 w-6 text-black transition-colors group-hover:text-black"
                      /> Reports & Analytics
                    </.link>
                  </div>
                  
    <!-- Footer -->
                  <div class="border-t border-gray-100 px-5 py-3 text-xs text-gray-500">
                    Goods System • v1.0
                  </div>
                </div>
              </aside>
              
    <!-- RIGHT CARD (WIDER + MORE DOMINANT) -->
              <section class="lg:col-span-9">
                <div class=" rounded-sm border border-gray-100 min-h-full">
                  
    <!-- CONTENT -->
                  <div class="p-2 ">
                    <img
                      class="w-full h-10 ring-dark rounded-t-2xl"
                      src={~p"/images/blue_pattern.png"}
                      alt="pattern"
                    />
                    {render_slot(@inner_block)}
                  </div>
                </div>
              </section>
            </div>
          </div>
        </main>
      </div>
    <% else %>
      <header class="navbar px-4 sm:px-6 lg:px-8 bg-white  flex items-center h-16">
        <div class="flex-1">
          <a
            href={~p"/"}
            class="inline-flex items-center gap-2 p-2 rounded-none
           focus:outline-3 focus:outline-dotted
          focus:outline-blue-500 focus:outline-offset-2"
          >
            <img
              src={~p"/images/logo1.svg"}
              class="h-10 w-auto "
              alt="ParcelTracker logo"
              width="80"
              height="80"
              fetchpriority="high"
              oncontextmenu="return false;"
            />
            <span class="sr-only">Home</span>
          </a>
        </div>

        <div class="hidden sm:flex">
          <ul class="menu menu-horizontal w-full relative z-10 flex items-center gap-4 px-4 py-2 sm:px-6 lg:px-8 justify-end">
            <li>
              <.button variant="primary">
                <.link navigate={~p"/sign-in"}>
                  Log In
                </.link>
              </.button>
            </li>
          </ul>
        </div>

        <button
          class="sm:hidden text-black font-bold text-lg"
          aria-label="Open menu"
          phx-click={
            JS.toggle(
              to: "#mobile-menu",
              in:
                {"transition transform ease-out duration-300", "scale-y-0 opacity-0",
                 "scale-y-100 opacity-100"},
              out:
                {"transition transform ease-in duration-200", "scale-y-100 opacity-100",
                 "scale-y-0 opacity-0"}
            )
          }
        >
          <.icon name="hero-bars-3" class="h-7 w-7" />
        </button>

        <div
          id="mobile-menu"
          class="fixed inset-0 bg-white z-50 flex flex-col px-6 py-8 scale-y-0 opacity-0 origin-top"
        >
          <div class="flex justify-between items-center mb-10">
            <img
              src={~p"/images/logo1.svg"}
              class="h-10 w-auto"
              alt="ParcelTracker logo"
              width="80"
              height="80"
              fetchpriority="high"
            />

            <button
              phx-click={JS.toggle(to: "#mobile-menu")}
              class="text-4xl"
              aria-label="Close menu"
            >
              &times;
            </button>
          </div>

          <nav class="flex flex-col space-y-6 text-lg">
            <.link
              navigate={~p"/sign-in"}
              class="bg-black text-white rounded-md px-6 py-3 text-center hover:bg-gray-900 transition-colors duration-300"
            >
              Sign in
            </.link>
          </nav>
        </div>
      </header>

      {render_slot(@inner_block)}
    <% end %>
    """
  end

  def nav_link(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@to}
        class="font-medium px-6 py-2 rounded-md hover:bg-gray-100 transition"
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end
end
