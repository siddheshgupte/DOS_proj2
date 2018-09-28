defmodule Application1 do
  use Application

  @gossip_limit 10

  def start(_type, num_of_nodes) do
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
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    Supervisor.which_children(supervisor)
  end
end
