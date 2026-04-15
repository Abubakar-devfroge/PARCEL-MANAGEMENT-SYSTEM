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
      <div id="sidebar-layout-container" class="min-h-screen bg-blue-50/60" phx-hook="SidebarHook">
        <div class="flex min-h-screen">
          <aside
            id="desktop-sidebar"
            class="hidden lg:flex lg:w-50 lg:fixed lg:inset-y-0 lg:z-40 font-sans antialiased"
          >
            <div
              id="desktop-sidebar-inner"
              class="flex grow flex-col overflow-y-auto  bg-red-700 px-5 py-6 transition-all duration-300"
            >
              <.link navigate={~p"/dash"} class="mb-8 flex items-center gap-3 px-1">
                <img
                  src={~p"/images/logo1.svg"}
                  class="h-15 w-auto rounded-full"
                  alt="ParcelTracker logo"
                  width="80"
                  height="80"
                  fetchpriority="high"
                  oncontextmenu="return false;"
                />
                <div></div>
              </.link>

              <nav class="space-y-1" aria-label="Sidebar">
                <.link
                  navigate={~p"/dash"}
                  class="desktop-nav-link group flex items-center justify-start gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-white transition duration-200 hover:bg-white/10 hover:text-white"
                >
                  <.icon
                    name="hero-home"
                    class="h-6 w-6 text-white transition-colors group-hover:text-white"
                  />
                  <span class="desktop-sidebar-label">Dashboard</span>
                </.link>

                <.link
                  navigate={~p"/parcel_bookings"}
                  class="desktop-nav-link group flex items-center justify-start gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-white transition duration-200 hover:bg-white/10 hover:text-white"
                >
                  <.icon
                    name="hero-archive-box"
                    class="h-6 w-6 text-white/90 transition-colors group-hover:text-white"
                  /> <span class="desktop-sidebar-label">Parcels</span>
                </.link>

                <.link
                  navigate={~p"/employees"}
                  class="desktop-nav-link group flex items-center justify-start gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-white transition duration-200 hover:bg-white/10 hover:text-white"
                >
                  <.icon
                    name="hero-users"
                    class="h-6 w-6 text-white/90 transition-colors group-hover:text-white"
                  /> <span class="desktop-sidebar-label">Employees</span>
                </.link>

                <.link
                  navigate={~p"/parcel_reports"}
                  class="desktop-nav-link group flex items-center justify-start gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-white transition duration-200 hover:bg-white/10 hover:text-white"
                >
                  <.icon
                    name="hero-document-text"
                    class="h-6 w-6 text-white/90 transition-colors group-hover:text-white"
                  /> <span class="desktop-sidebar-label">Reports</span>
                </.link>
              </nav>

              <div class="mt-auto border-t border-white/20 pt-4">
                <.link
                  navigate={~p"/parcel_reports"}
                  class="desktop-nav-link group flex items-center justify-start gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-white transition duration-200 hover:bg-white/10 hover:text-white"
                >
                  <.icon
                    name="hero-clock"
                    class="h-6 w-6 text-white/90 transition-colors group-hover:text-white"
                  /> <span class="desktop-sidebar-label">Activity logs</span>
                </.link>

                <.link
                  href={~p"/sign-out"}
                  class="desktop-nav-link group flex items-center justify-start gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-white transition duration-200 hover:bg-white/10 hover:text-white"
                >
                  <.icon
                    name="hero-arrow-right-on-rectangle"
                    class="h-6 w-6 text-white/90 transition-colors group-hover:text-white"
                  /> <span class="desktop-sidebar-label">Log out</span>
                </.link>
              </div>
            </div>
          </aside>

          <div id="desktop-main" class="flex flex-1 flex-col lg:pl-50 transition-all duration-300">
            <header class="sticky top-0 z-30 border-b border-gray-100 bg-white/95 shadow-sm backdrop-blur">
              <div class="flex h-14 items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
                <button
                  class="inline-flex items-center justify-center rounded-md bg-white p-2 text-gray-700 ring-1 ring-gray-300 transition hover:bg-gray-50 lg:hidden"
                  aria-label="Open menu"
                  phx-click={
                    JS.show(
                      to: "#mobile-sidebar-shell",
                      transition:
                        {"transition-opacity ease-out duration-200", "opacity-0", "opacity-100"}
                    )
                    |> JS.show(
                      to: "#mobile-sidebar-panel",
                      transition:
                        {"transition ease-out duration-200", "-translate-x-full", "translate-x-0"}
                    )
                  }
                >
                  <.icon name="hero-bars-3" class="h-6 w-6" />
                </button>

                <button
                  type="button"
                  id="sidebar-toggle-btn"
                  class="hidden lg:inline-flex items-center justify-center rounded-md bg-white p-2 text-gray-700 ring-1 ring-gray-300 transition hover:bg-gray-50"
                  aria-label="Toggle sidebar"
                >
                  <.icon name="hero-bars-3" class="h-6 w-6" />
                </button>

                <div class="ml-auto">
                  <el-dropdown class="inline-block">
                    <button class="inline-flex w-full justify-center gap-x-1.5 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-xs inset-ring-1 inset-ring-gray-300 hover:bg-gray-50">
                      {@current_user.email}
                      <svg
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        data-slot="icon"
                        aria-hidden="true"
                        class="-mr-1 size-5 text-gray-400"
                      >
                        <path
                          d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z"
                          clip-rule="evenodd"
                          fill-rule="evenodd"
                        />
                      </svg>
                    </button>

                    <el-menu
                      anchor="bottom end"
                      popover
                      class="w-56 origin-top-right rounded-md bg-white shadow-lg outline-1 outline-black/5 transition transition-discrete [--anchor-gap:--spacing(2)] data-closed:scale-95 data-closed:transform data-closed:opacity-0 data-enter:duration-100 data-enter:ease-out data-leave:duration-75 data-leave:ease-in"
                    >
                      <div class="py-1">
                        <a
                          href={~p"/profile?tab=personal"}
                          class="block px-4 py-2 text-sm text-gray-700 focus:bg-gray-100 focus:text-gray-900 focus:outline-hidden"
                        >
                          Account Management
                        </a>

                        <a
                          href={~p"/profile?tab=license"}
                          class="block px-4 py-2 text-sm text-gray-700 focus:bg-gray-100 focus:text-gray-900 focus:outline-hidden"
                        >
                          License
                        </a>

                        <.link
                          href={~p"/sign-out"}
                          class="block px-4 py-2 text-sm text-gray-700 focus:bg-gray-100 focus:text-gray-900 focus:outline-hidden"
                        >
                          Log out
                        </.link>
                      </div>
                    </el-menu>
                  </el-dropdown>
                </div>
              </div>
            </header>

            <main class="flex-1 px-2 py-4 sm:px-4 sm:py-6 lg:px-2 lg:py-4 bg-white">
              {render_slot(@inner_block)}
            </main>
          </div>
        </div>

        <div id="mobile-sidebar-shell" class="fixed inset-0 z-50 hidden lg:hidden" aria-hidden="true">
          <button
            type="button"
            class="absolute inset-0 bg-transparent"
            aria-label="Close menu"
            phx-click={
              JS.hide(
                to: "#mobile-sidebar-panel",
                transition: {"transition ease-in duration-150", "translate-x-0", "-translate-x-full"}
              )
              |> JS.hide(
                to: "#mobile-sidebar-shell",
                transition: {"transition-opacity ease-in duration-150", "opacity-100", "opacity-0"}
              )
            }
          >
          </button>

          <div
            id="mobile-sidebar-panel"
            class="relative flex h-full w-72 max-w-[85vw] -translate-x-full flex-col  bg-red-700 px-5 py-6"
          >
            <div class="mb-8 flex items-center justify-between">
              <.link navigate={~p"/dash"} class="flex items-center gap-3">
                <img
                  src={~p"/images/logo1.svg"}
                  class="h-10 w-auto rounded-full"
                  alt="ParcelTracker logo"
                  width="80"
                  height="80"
                  fetchpriority="high"
                  oncontextmenu="return false;"
                />
              </.link>

              <button
                type="button"
                class="rounded-md bg-white/10 p-2 text-white ring-1 ring-white/20 transition hover:bg-white/20"
                aria-label="Close menu"
                phx-click={
                  JS.hide(
                    to: "#mobile-sidebar-panel",
                    transition:
                      {"transition ease-in duration-150", "translate-x-0", "-translate-x-full"}
                  )
                  |> JS.hide(
                    to: "#mobile-sidebar-shell",
                    transition:
                      {"transition-opacity ease-in duration-150", "opacity-100", "opacity-0"}
                  )
                }
              >
                <.icon name="hero-x-mark" class="h-6 w-6" />
              </button>
            </div>

            <nav class="space-y-1" aria-label="Mobile sidebar">
              <.link
                navigate={~p"/dash"}
                class="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-white hover:bg-white/10"
              >
                <.icon name="hero-home" class="h-6 w-6 text-white/90" /> Dashboard
              </.link>
              <.link
                navigate={~p"/parcel_bookings"}
                class="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-white hover:bg-white/10"
              >
                <.icon name="hero-archive-box" class="h-6 w-6 text-white/90" /> Parcels
              </.link>
              <.link
                navigate={~p"/employees"}
                class="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-white hover:bg-white/10"
              >
                <.icon name="hero-users" class="h-6 w-6 text-white/90" /> Employees
              </.link>
              <.link
                navigate={~p"/profile"}
                class="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-white hover:bg-white/10"
              >
                <.icon name="hero-cog-6-tooth" class="h-6 w-6 text-white/90" /> Reports
              </.link>
            </nav>
          </div>
        </div>
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
