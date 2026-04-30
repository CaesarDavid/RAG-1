defmodule LocalRagWeb.ChatLive do
  use LocalRagWeb, :live_view

  alias LocalRag.RAG

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:thinking, false)
     |> assign(:question, "")}
  end

  @impl true
  def handle_event("update-question", %{"question" => q}, socket) do
    {:noreply, assign(socket, :question, q)}
  end

  @impl true
  def handle_event("ask", %{"question" => question}, socket) do
    question = String.trim(question)

    if question == "" do
      {:noreply, socket}
    else
      # Show user message immediately, then process async
      user_msg = %{role: :user, content: question, sources: []}
      messages = socket.assigns.messages ++ [user_msg]

      socket =
        socket
        |> assign(:messages, messages)
        |> assign(:question, "")
        |> assign(:thinking, true)

      send(self(), {:run_query, question})

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:run_query, question}, socket) do
    result =
      case RAG.query(question) do
        {:ok, %{answer: answer, sources: sources}} ->
          %{role: :assistant, content: answer, sources: sources}

        {:error, _reason} ->
          %{
            role: :assistant,
            content: "Sorry, I encountered an error processing your question. Please try again.",
            sources: []
          }
      end

    messages = socket.assigns.messages ++ [result]

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:thinking, false)}
  end
end
