defmodule Application1 do
  use Application
  use Task

  @gossip_limit 10

  def main(args \\ []) do
    {_,lst}= Application1.start(:abc, String.to_integer(Enum.at(args,0)), Enum.at(args,1), String.to_integer(Enum.at(args,3)))

    case Enum.at(args,2) do
      "pushsum" -> 
        GenServer.cast(:"Node 1", {:pushsum, [0, 0, true]})
      "gossip" ->
        GenServer.cast(:"Node 1", {:gossip, true})
    end

    start_timer = :erlang.system_time(:millisecond)
    Task.start_link(__MODULE__, :process, [start_timer, lst,self()])

    receive do
      {:hi, message} ->
        IO.puts message
    end

  end

  def connect_horizontally(ip_lst, step) do
    0..(length(ip_lst) - 1)
    |> Enum.to_list()
    |> Enum.each(fn x ->
      GenServer.cast(
        Enum.at(ip_lst, x),
        {:set_neighbours,
         Enum.filter(
           [
             if(x - step >= 0, do: Enum.at(ip_lst, x - step), else: nil),
             Enum.at(ip_lst, x + step)
           ],
           fn x -> x != nil end
         )}
      )
    end)

    if(step - 1 > 0) do
      connect_horizontally(ip_lst, step - 1)
    end
  end

  def connect_vertically(list_of_lists, step) do
    0..(length(list_of_lists) - 1)
    |> Enum.to_list()
    |> Enum.each(fn x ->
      0..(length(list_of_lists) - 1)
      |> Enum.to_list()
      |> Enum.each(fn y ->
        GenServer.cast(Enum.at(Enum.at(list_of_lists, x), y), {:set_neighbours,
         Enum.filter(
           #   [Enum.at(Enum.at(list_of_lists, x-step),y), Enum.at(Enum.at(list_of_lists,x+step), y)], 
           [
             if(x - step >= 0, do: Enum.at(Enum.at(list_of_lists, x - step), y), else: nil),
             if(x + step < length(list_of_lists),
               do: Enum.at(Enum.at(list_of_lists, x + step), y),
               else: nil
             )
           ],
           fn x -> x != nil end
         )})
      end)
    end)

    if(step - 1 > 0) do
      connect_vertically(list_of_lists, step - 1)
    end
  end

  # for torus
  def connect_horizontally(ip_lst) do
    0..(length(ip_lst) - 1)
    |> Enum.to_list()
    |> Enum.each(fn x ->
      GenServer.cast(
        Enum.at(ip_lst, x),
        {:set_neighbours,
         Enum.filter(
           [Enum.at(ip_lst, x - 1), Enum.at(ip_lst, rem(x + 1, length(ip_lst)))],
           fn x -> x != nil end
         )}
      )
    end)
  end

  def connect_vertically(list_of_lists) do
    0..(length(list_of_lists) - 1)
    |> Enum.to_list()
    |> Enum.each(fn x ->
      0..(length(list_of_lists) - 1)
      |> Enum.to_list()
      |> Enum.each(fn y ->
        GenServer.cast(Enum.at(Enum.at(list_of_lists, x), y), {
          :set_neighbours,
          #   [Enum.at(Enum.at(list_of_lists, x-step),y), Enum.at(Enum.at(list_of_lists,x+step), y)], 
          [
            Enum.at(Enum.at(list_of_lists, x - 1), y),
            Enum.at(Enum.at(list_of_lists, rem(x + 1, length(list_of_lists))), y)
          ]
        })
      end)
    end)
  end

  # calculate neighbours for 3D network
  def connect_neighbours3d(lst,n) do
    0..(n-1)
    |> Enum.to_list()
    |> Enum.each(fn x ->
      0..(n-1)
      |> Enum.to_list()
      |> Enum.each(fn y ->
        0..(n-1)
        |> Enum.to_list()
        |> Enum.each( fn z ->
          GenServer.cast(Enum.at(Enum.at(Enum.at(lst,x), y), z), {:set_neighbours,
          Enum.filter(
           #   [Enum.at(Enum.at(list_of_lists, x-step),y), Enum.at(Enum.at(list_of_lists,x+step), y)], 
           [
             if(x - 1 >= 0, do: Enum.at(Enum.at(Enum.at(lst,x-1), y), z), else: nil),
             if(x + 1 < n, do: Enum.at(Enum.at(Enum.at(lst,x+1), y), z), else: nil),
             if(y - 1 >= 0, do: Enum.at(Enum.at(Enum.at(lst,x), y-1), z), else: nil),
             if(y + 1 < n, do: Enum.at(Enum.at(Enum.at(lst,x), y+1), z), else: nil),
             if(z - 1 >= 0, do: Enum.at(Enum.at(Enum.at(lst,x), y), z-1), else: nil),
             if(z + 1 < n, do: Enum.at(Enum.at(Enum.at(lst,x), y), z+1), else: nil)
           ],
           fn x -> x != nil end
         )})
      end)
    end)
  end)

  end

  # Start the application with the number of nodes
  def start(_type, num_of_nodes, topology, failure) do
    # Create a list of children Supervisor.child_spec({Proj2, [10, :"Node 1"]},id: "Node 1")
    children =
      1..num_of_nodes
      |> Enum.to_list()
      |> Enum.map(fn x ->
        Supervisor.child_spec(
          {Proj2, [@gossip_limit, String.to_atom("Node #{x}"), x, failure]},
          id: String.to_atom("Node #{x}")
        )
      end)

    opts = [strategy: :one_for_one, name: Supervisor]

    # Get the supervisor in the supervisor variable
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    # Get a list of children of the supervisor
    lst =
      Supervisor.which_children(supervisor)
      |> Enum.map(fn x -> elem(x, 0) end)

    #   |>Enum.sort

    # creating ETS cache
    :ets.new(:registry, [:set, :public, :named_table])



    case topology do
      "full" ->
        # For Fully connected network
        # Set neighbours of the current node
        Enum.each(lst, fn x -> GenServer.cast(x, {:set_neighbours, List.delete(lst, x)}) end)

      "line" ->
        1..(num_of_nodes - 2)
        |> Enum.to_list()
        |> Enum.each(fn x ->
          GenServer.cast(
            Enum.at(lst, x),
            {:set_neighbours, [Enum.at(lst, x - 1), Enum.at(lst, x + 1)]}
          )
        end)

        GenServer.cast(:"Node 1", {:set_neighbours, [:"Node 2"]})

        GenServer.cast(
          String.to_atom("Node #{num_of_nodes}"),
          {:set_neighbours, [String.to_atom("Node #{num_of_nodes - 1}")]}
        )

      "imp2D" ->
        1..(num_of_nodes - 2)
        |> Enum.to_list()
        |> Enum.each(fn x ->
          GenServer.cast(
            Enum.at(lst, x),
            {:set_neighbours, [Enum.at(lst, x - 1), Enum.at(lst, x + 1), Enum.random(lst)]}
          )
        end)

        GenServer.cast(:"Node 1", {:set_neighbours, [:"Node 2", Enum.random(lst)]})

        GenServer.cast(
          String.to_atom("Node #{num_of_nodes}"),
          {:set_neighbours, [String.to_atom("Node #{num_of_nodes - 1}"), Enum.random(lst)]}
        )

      "rand2D" ->
        lst2= Enum.reverse(lst)
        len = trunc(:math.sqrt(num_of_nodes))
        truncated_list = Enum.take(lst2, trunc(:math.pow(len,2)))  

        list_of_lists = Enum.chunk_every(truncated_list, len)

        step = trunc(len / 10)

        if(step != 0) do
          Enum.each(list_of_lists, fn x -> connect_horizontally(x, step) end)
          connect_vertically(list_of_lists, step)
        end

      "torus" ->
        lst2= Enum.reverse(lst)
        len = trunc(:math.sqrt(num_of_nodes))
        truncated_list = Enum.take(lst2, trunc(:math.pow(len,2)))  

        list_of_lists = Enum.chunk_every(truncated_list, len)
        Enum.each(list_of_lists, fn x -> connect_horizontally(x) end)
        connect_vertically(list_of_lists)

      "3D" ->
        lst2= Enum.reverse(lst)
        n = trunc(:math.pow(num_of_nodes,1/3))
        truncated_list = Enum.take(lst2, trunc(:math.pow(n,3)))  
        array2d= Enum.chunk_every(truncated_list, trunc(:math.pow(n,2)))
        array3d= Enum.map(array2d, fn x -> Enum.chunk_every(x,n) end) |> IO.inspect 
        connect_neighbours3d(array3d,n)
    end
    {":ok",lst} # returning lst to main() for timer function
  end

  def process(start_timer, lst,pid) do
    receive do
    after
      5_00 ->
        len_lst2 =
          :ets.tab2list(:registry)
          |> length

        if len_lst2 >= length(lst)  do
          IO.inspect("Nodes dead #{len_lst2}")
          end_timer = :erlang.system_time(:millisecond)
          (end_timer - start_timer) |> IO.inspect()
          send pid, {:hi, "Successful"} # send message back to main() for termination
          Process.exit(self(), :normal)
        end

        process(start_timer, lst,pid)
    end
  end
end
