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
        :flag => true
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

    GenServer.cast(
      Enum.random(current_map.neighbour_list),
      {:pushsum, [current_map[:s], current_map[:w], false]}
    )

    #  If converged, exit
    if current_map[:current_pushsum_count] <= 0 do
      IO.inspect("Dead #{current_map[:s] / current_map[:w]}")

      # updating ETS cache before exiting
      :ets.insert(:registry, {self(),"Dead"})
      Process.exit(self(), :normal)
    end

    # {_, current_map} =
    #   if(current_map[:flag]) do
         sleep(500)
         GenServer.cast(self(), {:pushsum, [0.0, 0.0, true]})
         #          GenServer.cast(:"Node 45", {:pushsum, [0.0, 0.0, true]})
    #     Map.get_and_update(current_map, :flag, fn x -> {x, false} end)
    #   else 
    #    {"abc", current_map}
    #   end

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
