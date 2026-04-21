defmodule LocalRag.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  Since the app uses Turso (remote libSQL) instead of Postgres,
  there is no in-process sandbox. Tests that mutate data should
  clean up after themselves.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto.Changeset
      import LocalRag.DataCase
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
