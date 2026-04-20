defmodule LocalRagWeb.Router do
  use LocalRagWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LocalRagWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LocalRagWeb do
    pipe_through :browser

    live "/", UploadLive
    live "/chat", ChatLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", LocalRagWeb do
  #   pipe_through :api
  # end
end
