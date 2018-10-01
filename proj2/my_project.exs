import :timer
[arg1, arg2, arg3] = System.argv

# def start(_type, num_of_nodes, topology) do
Application1.start(:abc, String.to_integer(arg1), arg2)

case arg3 do
    "pushsum" -> 
       GenServer.cast(:"Node 1", {:pushsum, [0, 0, true]})
       IO.inspect "hello"
    "gossip" ->
        GenServer.cast(:"Node 1", :gossip)
        IO.inspect "hello"
    end
