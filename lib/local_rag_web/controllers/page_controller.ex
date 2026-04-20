defmodule LocalRagWeb.PageController do
  use LocalRagWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
