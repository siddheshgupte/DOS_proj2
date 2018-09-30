[arg1, arg2, arg3] = System.argv

# def start(_type, num_of_nodes, topology) do
Application1.start(:abc, String.to_integer(arg1), arg2)

case arg3 do
    "pushsum" -> 
       IO.inspect GenServer.cast(:"Node 1", {:pushsum, [0, 0, true]})
    "gossip" ->
       IO.inspect GenServer.cast(:"Node 1", :gossip)
    end
