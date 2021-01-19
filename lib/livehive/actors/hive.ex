defmodule Livehive.Actors.Hive do
	use Agent
  require Logger

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

	def join_or_create(hive_name, user_name) do
		Logger.warning "joining or creating #{hive_name} as user #{user_name}"
		maybe_hive = get(hive_name)
		hive = if maybe_hive do Map.put(maybe_hive, user_name, "neutral") else %{user_name => "neutral"} end
		save(hive_name, hive)
  end

  def get_hive(hive_name) do
		maybe_hive = get(hive_name)
		if maybe_hive do {:ok, maybe_hive} else {:error, "Tried to get data for a hive that doesn't exist."} end
	end

	def get_sentiment(hive_name, user_name) do
		Logger.warning "getting sentiment in #{hive_name} for user #{user_name}"
		maybe_hive = get(hive_name)
		Logger.warning maybe_hive
		if maybe_hive do
			if Map.get(maybe_hive, user_name) != nil do
				{:ok, Map.get(maybe_hive, user_name)}
			else
				{:error, "Tried to get specific sentiment data for a user that isn't in that hive."}
			end
		else
			{:error, "Tried to get specific sentiment data for a hive that doesn't exist."}
		end
	end

	def part(hive_name, user_name) do
		Logger.warning "parting hive #{hive_name} as user #{user_name}"
		maybe_hive = get(hive_name)
		hive = if maybe_hive do Map.delete(maybe_hive, user_name) else false end
		if hive !== false and Enum.count(hive) > 0 do save(hive_name, hive) else close(hive_name) end
	end

	def part_without_closing(hive_name, user_name) do
		Logger.warning "parting hive #{hive_name} as user #{user_name}, without closing hive if empty"
		maybe_hive = get(hive_name)
		hive = if maybe_hive do Map.delete(maybe_hive, user_name) else false end
		if hive !== false do save(hive_name, hive) end
	end

	def update(hive_name, user_name, new_sentiment) do
		Logger.warning "#{user_name} updating #{hive_name} with sentiment #{new_sentiment}"
		maybe_hive = get(hive_name)
		cond do
			maybe_hive == false ->
				{:error, "Tried to update a sentiment for a hive that doesn't exist."}
			Map.get(maybe_hive, user_name) == nil ->
				{:error, "Tried to update a sentiment for a user that isn't in the hive."}
			true ->
				{:ok, save(hive_name, Map.put(maybe_hive, user_name, new_sentiment))}
		end
  end

  defp get(room) do
		room = Agent.get(__MODULE__, fn(state) -> state[room] end)
		if is_nil(room) do false else room end
  end

	defp save(hive_name, hive) do
		Agent.update(__MODULE__,
			fn state ->
				Map.put(state, hive_name, hive)
			end)
		hive
  end

	defp close(hive_name) do
		Logger.critical "closing #{hive_name}!"
		Agent.update(__MODULE__,
			fn state ->
				Map.delete(state, hive_name)
			end)
		nil
	end

end
