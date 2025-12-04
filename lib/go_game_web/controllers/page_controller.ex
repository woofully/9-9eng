defmodule GoGameWeb.PageController do
  use GoGameWeb, :controller

  def home(conn, _params) do
    # Check if user is logged in
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      redirect(conn, to: "/lobby")
    else
      render(conn, :home)
    end
  end
end
