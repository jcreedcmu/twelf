
local
structure S = Parser.Stream
in

fun regToString(Paths.Reg(a, b)) = "[" ^ (Int.toString a) ^ "," ^ (Int.toString b) ^ "]"

fun printDecl (Parser.ConDec(_), reg) = print("condec" ^ regToString(reg) ^ "\n")
  | printDecl (Parser.FixDec(fd), reg) = print("fixdec\n")
  | printDecl _ = ()

fun printParseResult str = let
  val parsed = Parser.parseStream (TextIO.openString str)
fun p s = p' (S.expose s)
and p' S.Empty = ()
  | p' (S.Cons(decl, s')) = (printDecl decl; p s')
in
  p parsed
  handle (Parsing.Error s) => print("parse error: (" ^ s ^ ")\n")
		| _ => print("unknown error occurred")
end

end
