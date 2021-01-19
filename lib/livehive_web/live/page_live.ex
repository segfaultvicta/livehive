defmodule LivehiveWeb.PageLive do
  use LivehiveWeb, :live_view
  alias Livehive.Actors.Hive
  alias LivehiveWeb.Endpoint
  require Logger

  # What happens if two people try to have the same name?

  @impl true
  def mount(%{"hive_name" => _}, _, socket) do
    {:ok, assign(socket, hive_joined: false, user_name: generate_name(), anonymous: true, show_name: "hide", validate_class: "hive-empty")}
  end

  @impl true
  def mount(_, _, socket) do
    {:ok, assign(socket, hive_joined: false, user_name: "", anonymous: true, show_name: "hide", validate_class: "hive-empty")}
  end

  @impl true
  def terminate(_, socket) do
    if socket.assigns.user_name != "" do
      Hive.part(socket.assigns.hive_name, socket.assigns.user_name)
      Endpoint.broadcast(topic(socket.assigns.hive_name), "update", %{})
      Endpoint.unsubscribe(topic(socket.assigns.hive_name))
    end
  end

  @impl true
  def handle_params(%{"hive_name" => name}, _, socket) do
    if connected?(socket) do
      hive = Hive.join_or_create(name, socket.assigns.user_name)
      Endpoint.subscribe(topic(name))
      Endpoint.broadcast_from(self(), topic(name), "update", %{})
      {:noreply, assign(socket,
        hive_joined: true, hive_name: name, show_name: "show",
        selected: build_selected("neutral"), hive: build_sentiment_map(hive)
      )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validateHive", %{"hiveName" => name}, socket) do
    {status, _} = Hive.get_hive(name)
    vc = if name == "" do "hive-empty" else if status == :ok do "hive-exists" else "hive-missing" end end
    {:noreply, assign(socket, validate_class: vc)}
  end

  @impl true
  def handle_event("enterHive", %{"hiveName" => name}, socket) do
    username = if socket.assigns.anonymous do generate_name() else socket.assigns.user_name end
    #hive = Hive.join_or_create(name, username)
    #Endpoint.subscribe(topic(name))
    #Endpoint.broadcast_from(self(), topic(name), "update", %{})
    #{:noreply, push_patch(socket, to: Routes.page_path(socket, :index, name))}

    {:noreply,
      push_patch(
        assign(socket, user_name: username),
        to: Routes.page_path(socket, :index, name)
      )
    }
  end

  @impl true
  def handle_event("leaveHive", _v, socket) do
    Hive.part(socket.assigns.hive_name, socket.assigns.user_name);
    Endpoint.broadcast(topic(socket.assigns.hive_name), "update", %{})
    Endpoint.unsubscribe(topic(socket.assigns.hive_name))
    {:noreply,
      push_patch(
        assign(socket, hive_joined: false, show_name: "hide", validate_class: "hive-empty"),
        to: Routes.page_path(socket, :index)
      )
    }
  end

  @impl true
  def handle_event("changeName", %{"userName" => newUsername}, socket) do
    # need to part the old username from the hive and add the new username,
    # remembering the user's currently selected sentiment
    rename_user(socket.assigns.hive_name, socket.assigns.user_name, newUsername)
    Endpoint.broadcast(topic(socket.assigns.hive_name), "update", %{})
    {:noreply, assign(socket, user_name: newUsername, anonymous: false)}
  end

  @impl true
  def handle_event("anonymise", _v, socket) do
    newUsername = generate_name()
    # same as above, need to rename the user in the hive
    rename_user(socket.assigns.hive_name, socket.assigns.user_name, newUsername)
    Endpoint.broadcast(topic(socket.assigns.hive_name), "update", %{})
    {:noreply, assign(socket, user_name: newUsername, anonymous: true)}
  end

  @impl true
  def handle_event("changeSentiment", %{"sentiment" => sentiment}, socket) do
    Hive.update(socket.assigns.hive_name, socket.assigns.user_name, sentiment)
    Endpoint.broadcast(topic(socket.assigns.hive_name), "update", %{})
    {:noreply, assign(socket, selected: build_selected(sentiment))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "update", payload: _v, topic: _h}, socket) do
    Logger.debug "#{socket.assigns.user_name} in #{socket.assigns.hive_name} receiving update order"
    {status, hive} = Hive.get_hive(socket.assigns.hive_name)
    if status == :ok do
      Logger.info build_sentiment_map(hive)
      {:noreply, assign(socket, hive: build_sentiment_map(hive))}
    else
      Logger.critical "error retrieving hive #{socket.assigns.hive_name} in update routine"
      {:noreply, socket}
    end
  end

  def render_blocker_message(blocker) do
    case blocker.sentiment do
      "question" -> "#{blocker.username} has a question."
      "order" -> "#{blocker.username} raises a point of order."
      "hand" -> "#{blocker.username} wants a chance to speak."
      "hardno" -> "#{blocker.username} has a serious problem."
      _ -> ""
    end
  end

  defp build_selected(sentiment) do
    %{happy: build_part("happy", sentiment),
    neutral: build_part("neutral", sentiment),
    sad: build_part("sad", sentiment),
    question: build_part("question", sentiment),
    order: build_part("order", sentiment),
    hand: build_part("hand", sentiment),
    hardno: build_part("hardno", sentiment),}
  end

  defp build_part(sentiment, compare) do
    if sentiment == compare do "sentiment-selected" else "sentiment-unselected" end
  end

  defp topic(hive_name) do
    "hive:#{hive_name}"
  end

  defp rename_user(hive, old_name, new_name) do
    # get old_name sentiment and save it to assign to the new username
    Logger.debug "renaming user #{old_name} in hive #{hive} to #{new_name}"
    {_, sentiment} = Hive.get_sentiment(hive, old_name)
    Logger.debug "previous sentiment was #{sentiment}"
    # part old_name from hive
    Hive.part_without_closing(hive, old_name)
    # join new_name to hive with sentiment saved previously
    Hive.join_or_create(hive, new_name)
    Hive.update(hive, new_name, sentiment)
  end

  defp generate_name do
		:rand.seed(:exsplus)
		[Application.get_env(:livehive, :adjectives), Application.get_env(:livehive, :nouns)]
		|> Enum.map(&Enum.random/1)
		|> Enum.map(&String.capitalize/1)
		|> Enum.join(" ");
  end

  defp build_sentiment_map(hive, username \\ "") do
		{happy, neutral, sad} = calculate_temperature(hive)
		blocks = hive
			|> Map.to_list
			|> Enum.filter(fn({_, sentiment}) -> sentiment in Application.get_env(:livehive, :blocking_sentiments) end)
			|> Enum.map(fn({user, sentiment}) -> %{username: user, sentiment: sentiment} end)
		%{name: username, happy: happy, neutral: neutral, sad: sad, blocks: blocks}
	end

	defp calculate_temperature(hive) do
		room_count = Enum.count(hive)
		happy_count = hive |> Map.to_list |> Enum.filter(fn({_,y}) -> y in Application.get_env(:livehive, :happy_sentiments) end) |> Enum.count
		sad_count = hive |> Map.to_list |> Enum.filter(fn({_,y}) -> y in Application.get_env(:livehive, :sad_sentiments) end) |> Enum.count
		happy_ratio = happy_count / room_count
		sad_ratio = sad_count / room_count
		happies = round(happy_ratio * 100)
		sads = round(sad_ratio * 100)
		neutrals = 100 - (happies + sads)
		{happies, neutrals, sads}
	end
end
