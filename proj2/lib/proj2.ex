import :timer

defmodule Proj2 do
  use GenServer, restart: :temporary

  # External API
  def start_link([gossip_limit, input_name, node_index]) do
    GenServer.start_link(
      __MODULE__,
      %{
        :current_gossip_count => gossip_limit,
        :neighbour_list => [],
        :s => node_index,
        :w => 1,
        :current_pushsum_count => 3,
        :is_first => true,
        :name => input_name
      },
      name: input_name
    )
  end

  # Genserver Implementation
  def init(initial_map) do
    {:ok, initial_map}
  end

  def handle_call(:gossip, _from, current_map) do
    {_, updated_map} =
      Map.get_and_update(current_map, :current_gossip_count, fn x -> {x, x - 1} end)

    {:reply, current_map, updated_map}
  end

  def handle_cast(:gossip, current_map) do
    IO.puts(current_map.current_gossip_count)

    if current_map.current_gossip_count <= 0 do
      # GenServer.cast(self(), :kill_self)
      Process.exit(self(), :normal)
    end

    GenServer.cast(Enum.random(current_map.neighbour_list), :gossip)

    {_, updated_map} =
      Map.get_and_update(current_map, :current_gossip_count, fn x -> {x, x - 1} end)

    sleep(100)
    GenServer.cast(self(), :gossip)
    {:noreply, updated_map}
  end

  def handle_cast({:pushsum, [input_s, input_w, is_self]}, current_map) do

    # IO.inspect current_map.name
    
    #  Calculate previous ratio
    prev_ratio = current_map[:s] / current_map[:w]

    # Update s and w values
    {_, current_map} = Map.get_and_update(current_map, :s, fn x -> {x, x + input_s} end)
    {_, current_map} = Map.get_and_update(current_map, :w, fn x -> {x, x + input_w} end)

    #  Calculate current ratio
    current_ratio = current_map[:s] / current_map[:w]

    {_, current_map} =
      if not is_self do
        #  Check for convergence
        if current_ratio - prev_ratio < 10.0e-10 do
          Map.get_and_update(current_map, :current_pushsum_count, fn x -> {x, x - 1} end)
        else
          {"abc", current_map}
        end
      else
        {"abc", current_map}
      end

    # Keep half of s and w
    {_, current_map} = Map.get_and_update(current_map, :s, fn x -> {x, x / 2} end)
    {_, current_map} = Map.get_and_update(current_map, :w, fn x -> {x, x / 2} end)

    #  Message a random neighbour
    GenServer.cast(
      Enum.random(current_map.neighbour_list),
      {:pushsum, [current_map[:s], current_map[:w], false]}
    )

    # # # Random failure
    # if Enum.random(0..99) < 1 do
    #   IO.inspect("Died due to failure")
    #   :ets.insert(:registry, {current_map.name,"Dead"})
    #   Process.exit(self(), :normal)
    # end

    #  If converged, exit
    if current_map[:current_pushsum_count] <= 0 do
      IO.inspect("Dead #{current_map[:s] / current_map[:w]}")

      # updating ETS cache before exiting
      :ets.insert(:registry, {current_map.name, "Dead"})
      Process.exit(self(), :normal)
    end

    #  Check if this is from an external node and is not the first message from an external node
    if not is_self and not current_map[:is_first] do
      {:noreply, current_map}
    end

    {_, current_map} =
      if not is_self and current_map[:is_first] do
        Map.get_and_update(current_map, :is_first, fn x -> {x, false} end)
      else
        {"abc", current_map}
      end

    sleep(1000)
    # Check if there are dead neighbours
    dead_neighbours =
      Enum.map(current_map.neighbour_list, fn x -> if :ets.lookup(:registry, x) != [], do: x end)
      |> Enum.filter(fn x -> x != nil end)

    if length(dead_neighbours) == length(current_map.neighbour_list) do
      IO.inspect(dead_neighbours)
      IO.inspect("Dying because all neighbours dead")
      # updating ETS cache before exiting
      :ets.insert(:registry, {current_map.name, "Dead"})
      Process.exit(self(), :normal)
    end

    GenServer.cast(self(), {:pushsum, [0.0, 0.0, true]})

    {:noreply, current_map}
  end

  def handle_cast({:set_neighbours, list_of_neighbours}, current_map) do
    {_, updated_map} =
      Map.get_and_update(current_map, :neighbour_list, fn x -> {x, x ++ list_of_neighbours} end)

    IO.inspect(updated_map)
    {:noreply, updated_map}
  end

  def handle_cast(:kill_self, current_map) do
    {:stop, :normal, current_map}
  end

  def terminate(_, current_map) do
    IO.inspect("Dead")
  end
end

# GenServer.cast(:"Node 1", {:pushsum, [0, 0, true]})
