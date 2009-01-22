(* Syntax and semantics of the module system, also encapsulation of the state of modular LF *)
(* Author: Florian Rabe *)

(* The datatypes and interface methods are well-documented in the declaration of MODSYN. *)
functor ModSyn (structure IntSyn : INTSYN)
  : MODSYN =
struct
  structure CH = CidHashTable
  structure CCH = HashTable (type key' = IDs.cid * IDs.cid
             val hash = fn (x,y) => 100 * (IDs.cidhash x) + (IDs.cidhash y)
             val eq = (op =));
  structure IH = IntHashTable
  structure I = IntSyn

  exception Error of string

  datatype Morph = MorStr of IDs.cid | MorView of IDs.mid | MorComp of Morph * Morph
  datatype SymInst = ConInst of IDs.cid * I.Exp | StrInst of IDs.cid * Morph
  datatype StrDec = StrDec of string list * IDs.qid * IDs.mid * (SymInst list)
                  | StrDef of string list * IDs.qid * IDs.mid * Morph
  datatype ModDec = SigDec of string list | ViewDec of string * IDs.mid * IDs.mid

  (* unifies constant and structure declarations *)
  datatype SymDec = SymCon of I.ConDec | SymStr of StrDec

  fun strDecName (StrDec(n, _, _, _)) = n
    | strDecName (StrDef(n, _, _, _)) = n
  fun strDecFoldName s =  IDs.mkString(strDecName s,"",".","")
  fun strDecQid (StrDec(_, q, _, _)) = q
    | strDecQid (StrDef(_, q, _, _)) = q
  fun strDecDom (StrDec(_, _, m, _)) = m
    | strDecDom (StrDef(_, _, m, _)) = m

  fun symInstCid(ConInst(c, _)) = c
    | symInstCid(StrInst(c, _)) = c

  exception UndefinedCid of IDs.cid
  exception UndefinedMid of IDs.mid
  
  (********************** Stateful data structures **********************)

    (* Invariants *)
    (* Constant declarations are all well-typed *)
    (* Constant declarations are stored in beta-normal form *)
    (* All definitions are strict in all their arguments *)
    (* If Const(cid) is valid, then sgnArray(cid) = ConDec _ *)
    (* If Def(cid) is valid, then sgnArray(cid) = ConDef _ *)

   (*
   Invariants
   Every declaration for s_1. ... .s_n.c generated by the module system can be seen as the result of applying
   - s_1. ... .s_n to c,
   - s_1. ... .s_{n-1} to s_n.c,
   - ..., or
   - s_1 to s_2. ... .s_n.c.
   If sgnTable contains (cid, condec) and cid represents the constant s_1. ... .s_n.c, then
   - (conDecQid condec) is [(CID(s_1. ... .s_n), CID(c)), ... ,(CID(s_1), CID(s_2. ... .s_n.c))],
   - (conDecName condec) is [s_1, ..., s_n, c].
   For declarations that are not generated by the module system the former is nil, and the latter has length 1.
   For structures, the corresponding invariant holds about structTable.
   For structures, also the inverse of this mapping cid -> qid is maintained:
   structMapTable contains for pairs (S,s') of structure ids, the id of the structure arising from applying S to s'.
  *)
  (* maps modules IDs to module declarations, sizes, and containing module; size is -1 if the module is still open *)
  val modTable : (ModDec * int * (IDs.mid option)) IH.Table = IH.new(499)
  (* maps symbol ids to constant declarations *)
  val symTable : I.ConDec CH.Table = CH.new(19999)
  (* maps symbol ids to structure declarations *)
  val structTable : StrDec CH.Table = CH.new(999)
  (* maps pairs of (CID(S), CID(s')) of structure ids to the structure id CID(S.s') *)
  val structMapTable : IDs.cid CCH.Table = CCH.new(1999)
   
  (* scope holds a list of the currently opened modules and their next available lid (in inverse declaration order) *)
  val scope : (IDs.mid * IDs.lid) list ref = ref nil
  (* the next available module id *)
  val nextMid : IDs.mid ref = ref 0

  (********************** End stateful data structures **********************)

  fun currentMod() = #1 (hd (! scope))
  fun getScope () = map #1 (! scope)
  fun onToplevel() = List.length (! scope) = 1
  fun inCurrent(l : IDs.lid) = IDs.newcid(currentMod(), l)

  fun modLookup(m : IDs.mid) = #1 (valOf (IH.lookup modTable m))
                               handle Option => raise UndefinedMid(m)
  fun modSize(m : IDs.mid) =
     case List.find (fn (x,_) => x = m) (! scope)
        of SOME (_,l) => l                             (* size of open module stored in scope *)
         | NONE => #2 (valOf (IH.lookup modTable m))   (* size of closed module stored in modTable *)
                   handle Option => raise UndefinedMid(m)
  fun modParent(m : IDs.mid) = #3 (valOf (IH.lookup modTable m))
                               handle Option => raise UndefinedMid(m)
  fun modOpen(sigDec as SigDec _) =
     let
     	val parent = currentMod()
     	val _ = case modLookup parent
     	          of ViewDec _ => raise Error("signatures may not occur inside views")
     	           | _ => ()
        val m = ! nextMid
        val _ = nextMid := ! nextMid + 1
        val _ = scope := (m,0) :: (! scope)
        val _ = IH.insert modTable (m, (sigDec, ~1, SOME parent))
     in
     	m
     end
    | modOpen(viewDec as ViewDec _) = raise Error("views are currently not implemented") (* @FR *)
  fun modClose() =
    if onToplevel()
    then raise Error("no open module to close")
    else
      let
         val (m,l) = hd (! scope)
         val _ = scope := tl (! scope)
         val _ = IH.insert modTable (m, (modLookup m, l, modParent m))
      in
         ()
      end

  fun sgnAddC (conDec : I.ConDec) =
    let
      val (c as (m,l)) :: scopetail = ! scope
      val q = I.conDecQid conDec
    in
      CH.insert(symTable)(c, conDec);
      scope := (m, l+1) :: scopetail;
      (* q = [(s_1,c_1),...,(s_n,c_n)] where every s_i maps c_i to c *)
      List.map (fn sc => CCH.insert structMapTable (sc, c)) q;
      c
    end
      
  fun sgnLookup (c : IDs.cid) = case CH.lookup(symTable)(c)
    of SOME d => d
     | NONE => raise (UndefinedCid c)
  val sgnLookupC = sgnLookup o inCurrent

  fun structAddC(strDec : StrDec) =
    let
      val (c as (m,l)) :: scopetail = ! scope
      val _ = scope := (m, l+1) :: scopetail
      val _ = CH.insert(structTable)(c, strDec)
    in
      c
    end
  fun structLookup(c : IDs.cid) = case CH.lookup(structTable)(c)
    of SOME d => d
  | NONE => raise (UndefinedCid c)
  val structLookupC = structLookup o inCurrent
  fun structMapLookup (S,s') = CCH.lookup structMapTable (S,s')

  fun symLookup(c : IDs.cid) =
    SymStr(structLookup c)
    handle UndefinedCid _ => SymCon(sgnLookup c)
  fun symQid(c : IDs.cid) = case symLookup c
       of SymCon condec => I.conDecQid condec
        | SymStr strdec => strDecQid strdec

  fun modApp(f : IDs.mid -> unit) =
    let
      val length = ! nextMid
      fun doRest(m) = 
	if m = length then () else ((f m); doRest(m+1))
    in
      doRest(0)
    end
    
  fun sgnApp(m : IDs.mid, f : IDs.cid -> unit) =
    let
      val length = modSize m
      fun doRest(l) =
	if l = length then () else (f (m,l); doRest(l+1))
    in
      doRest(0)
    end
  fun sgnAppC (f) = sgnApp(currentMod(), f)

  fun reset () = (
    CH.clear symTable;               (* clear tables *)
    CH.clear structTable;
    IH.clear modTable;
    CCH.clear structMapTable;
    nextMid := 1;                    (* initial mid *)
    scope := [(0,0)];                (* toplevel with mid 0 and no parent is always open *)
    IH.insert modTable (0, (SigDec ["toplevel"], ~1, NONE))  
  )
 
  (********************** Convenience methods **********************)
  fun constDefOpt (d) =
      (case sgnLookup (d)
	 of I.ConDef(_, _, _, U,_, _, _) => SOME U
	  | I.AbbrevDef (_, _, _, U,_, _) => SOME U
	  | _ => NONE)
  val constDef = valOf o constDefOpt
  fun constType (c) = I.conDecType (sgnLookup c)
  fun constImp (c) = I.conDecImp (sgnLookup c)
  fun constUni (c) = I.conDecUni (sgnLookup c)
  fun constBlock (c) = I.conDecBlock (sgnLookup c)
  fun constStatus (c) =
      (case sgnLookup (c)
	 of I.ConDec (_, _, _, status, _, _) => status
          | _ => I.Normal)
  fun symFoldName(c) =
     case symLookup(c)
       of SymCon(condec) => IntSyn.conDecFoldName condec
        | SymStr(strdec) => strDecFoldName strdec
  fun modFoldName m =
    case modLookup m 
       of SigDec n => IDs.mkString(n,"",".","")
        | ViewDec(n, _, _) => n

 
  (********************** Convenience methods **********************)
  fun ancestor' (NONE) = I.Anc(NONE, 0, NONE)
    | ancestor' (SOME(I.Const(c))) = I.Anc(SOME(c), 1, SOME(c))
    | ancestor' (SOME(I.Def(d))) =
      (case sgnLookup(d)
	 of I.ConDef(_, _, _, _, _, _, I.Anc(_, height, cOpt))
            => I.Anc(SOME(d), height+1, cOpt))
    | ancestor' (SOME _) = (* FgnConst possible, BVar impossible by strictness *)
      I.Anc(NONE, 0, NONE)
  (* ancestor(U) = ancestor info for d = U *)
  fun ancestor (U) = ancestor' (I.headOpt U)

  (* defAncestor(d) = ancestor of d, d must be defined *)
  fun defAncestor (d) =
      (case sgnLookup(d)
	 of I.ConDef(_, _, _, _, _, _, anc) => anc)

  (* targetFamOpt (V) = SOME(cid) or NONE
     where cid is the type family of the atomic target type of V,
     NONE if V is a kind or object or have variable type.
     Does expand type definitions.
  *)
  fun targetFamOpt (I.Root (I.Const(c), _)) = SOME(c)
    | targetFamOpt (I.Pi(_, V)) = targetFamOpt V
    | targetFamOpt (I.Root (I.Def(c), _)) = targetFamOpt (constDef c)
    | targetFamOpt (I.Redex (V, S)) = targetFamOpt V
    | targetFamOpt (I.Lam (_, V)) = targetFamOpt V
    | targetFamOpt (I.EVar (ref (SOME(V)),_,_,_)) = targetFamOpt V
    | targetFamOpt (I.EClo (V, s)) = targetFamOpt V
    | targetFamOpt _ = NONE
      (* Root(Bvar _, _), Root(FVar _, _), Root(FgnConst _, _),
         EVar(ref NONE,..), Uni, FgnExp _
      *)
      (* Root(Skonst _, _) can't occur *)
  (* targetFam (A) = a
     as in targetFamOpt, except V must be a valid type
  *)
  fun targetFam (A) = valOf (targetFamOpt A)

  (* was used only by Flit, probably violates invariants
  fun rename (c, conDec : I.ConDec) =
    CH.insert(symTable)(c, conDec)
   *)
end (* functor ModSyn *)


(* ModSyn is instantiated with IntSyn right away. Both are visible globally. *)
structure ModSyn =
  ModSyn (structure IntSyn = IntSyn);

