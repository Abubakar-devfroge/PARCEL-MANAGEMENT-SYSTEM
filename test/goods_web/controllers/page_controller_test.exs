defmodule GoodsWeb.PageControllerTest do
  use GoodsWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = conn |> Map.put(:scheme, :https) |> Map.put(:host, "localhost") |> get(~p"/")
    assert html_response(conn, 200) =~ "Grow Smarter"
  end
end
