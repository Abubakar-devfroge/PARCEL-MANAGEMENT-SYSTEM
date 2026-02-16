defmodule GoodsWeb.PageController do
  use GoodsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
