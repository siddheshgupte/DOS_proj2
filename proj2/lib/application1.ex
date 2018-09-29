defmodule Application1 do
  use Application

  @gossip_limit 10

# Start the application with the number of nodes
  def start(_type, num_of_nodes, topology) do

    # Create a list of children Supervisor.child_spec({Proj2, [10, :"Node 1"]},id: "Node 1")
    children =
      1..num_of_nodes
      |> Enum.to_list()
      |> Enum.map(fn x ->
        Supervisor.child_spec(
          {Proj2, [@gossip_limit, String.to_atom("Node #{x}")]},
          id: String.to_atom("Node #{x}")
        )
      end)

    opts = [strategy: :one_for_one, name: Supervisor]
    
    # Get the supervisor in the supervisor variable
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    # Get a list of children of the supervisor
    lst = Supervisor.which_children(supervisor)
        |> Enum.map(fn x -> elem(x, 0) end)

    case topology do
        "full" ->            
            # For Fully connected network
            # Set neighbours of the current node
            Enum.each(lst, fn x -> GenServer.cast(x, {:set_neighbours, List.delete(lst, x)}) end)
        "line" ->
            1..(num_of_nodes-2)
                |> Enum.to_list
                |> Enum.each( fn x -> GenServer.cast(Enum.at(lst, x), {:set_neighbours, [Enum.at(lst, x-1), Enum.at(lst, x+1)]}) end)

            GenServer.cast(:"Node 1", {:set_neighbours, [:"Node 2"]})
            GenServer.cast(String.to_atom("Node #{num_of_nodes}"), {:set_neighbours, [String.to_atom("Node #{num_of_nodes - 1}")]})
            
    end
    
  end
end
