import :timer
defmodule Proj2 do
  use GenServer, restart: :temporary

  # External API
  def start_link([gossip_limit, input_name]) do
    GenServer.start_link(
      __MODULE__,
      %{:current_gossip_count => gossip_limit, :neighbour_list => []},
      name: input_name
    )
  end

  # Genserver Implementation
  def init(initial_map) do
    {:ok, initial_map}
  end

  def handle_call(:gossip, _from, current_map) do
    {_, updated_map} = Map.get_and_update(current_map, :current_gossip_count, fn x -> {x, x - 1} end)
    {:reply, current_map, updated_map}
  end

  def handle_cast(:gossip, current_map) do

    IO.puts current_map.current_gossip_count

    if current_map.current_gossip_count <= 0 do
      # GenServer.cast(self(), :kill_self)
      Process.exit(self(), :normal)
    end

    GenServer.cast(Enum.random(current_map.neighbour_list), :gossip)

    {_, updated_map} = Map.get_and_update(current_map, :current_gossip_count, fn x -> {x, x - 1} end)

    sleep 100
    GenServer.cast(self(), :gossip)
    {:noreply, updated_map}
  end

  def handle_cast({:set_neighbours, list_of_neighbours}, current_map) do
    {_,updated_map} = Map.get_and_update(current_map, :neighbour_list, fn x -> {x, list_of_neighbours} end)
    IO.inspect updated_map
    {:noreply, updated_map}
  end

  def handle_cast(:kill_self, current_map) do
    {:stop, :normal, current_map}
  end

  def terminate(_, current_map) do
    IO.inspect "Dead"
  end
end
