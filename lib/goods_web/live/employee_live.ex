defmodule GoodsWeb.EmployeeLive do
  use GoodsWeb, :live_view

  alias Goods.Accounts.Employees

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_user, fn -> nil end)
      |> assign(:page_title, "Employees")
      |> assign(:search_query, "")
      |> assign(:show_add_modal, false)
      |> assign(:employee_form, employee_form())
      |> stream(:employees, [])

    if admin?(socket.assigns.current_user) do
      {:ok, reload_employees(socket)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Only managers can access employee management")
       |> redirect(to: ~p"/dash")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query |> to_string() |> String.trim())
     |> reload_employees()}
  end

  @impl true
  def handle_event("open_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_modal, true)
     |> assign(:employee_form, employee_form())}
  end

  @impl true
  def handle_event("close_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, false)}
  end

  @impl true
  def handle_event("validate_employee", %{"employee" => params}, socket) do
    {:noreply, assign(socket, :employee_form, employee_form(params))}
  end

  @impl true
  def handle_event("create_employee", %{"employee" => params}, socket) do
    attrs = normalize_employee_params(params)

    case Employees.create_employee(socket.assigns.current_user, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee created and invite email sent")
         |> assign(:show_add_modal, false)
         |> assign(:employee_form, employee_form())
         |> reload_employees()}

      {:error, {:invite_email_failed, _user, reason}} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Employee created, but invite email failed. Reason: #{format_reason(reason)}"
         )
         |> assign(:show_add_modal, false)
         |> assign(:employee_form, employee_form())
         |> reload_employees()}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not create employee: #{format_reason(error)}")
         |> assign(:employee_form, employee_form(params))}
    end
  end

  defp reload_employees(socket) do
    employees = Employees.list(socket.assigns.current_user, socket.assigns.search_query)

    socket
    |> stream(:employees, employees, reset: true)
    |> assign(:employees_count, length(employees))
  end

  defp employee_form(params \\ %{}) do
    defaults = %{"name" => "", "email" => "", "role" => "agent"}
    to_form(Map.merge(defaults, params), as: "employee")
  end

  defp normalize_employee_params(params) do
    %{
      name: params |> Map.get("name", "") |> String.trim(),
      email: params |> Map.get("email", "") |> String.trim(),
      role: role_from_input(params |> Map.get("role", "agent"))
    }
  end

  defp role_from_input("admin"), do: :admin
  defp role_from_input("agent"), do: :agent
  defp role_from_input(_), do: :agent

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  defp format_reason(%Ash.Error.Invalid{} = error), do: inspect(error)

  defp format_reason(%Ash.Error.Forbidden{}), do: "not authorized"
  defp format_reason(reason), do: inspect(reason)

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M")
  end
end
