structure SigINT :> SIGINT =
struct

  fun interruptLoop (loop:unit -> unit) = ()

end;  (* structure SigINT *)
