open GT

module Expr = struct
    @type 'self t =
    [ `Var   of string
    | `Const of int
    | `Binop of (int -> int -> int) * string * 'self * 'self
    ]

    class ['a] toString (fself: unit -> 'a -> string) =
      object
        inherit [unit, 'a, string, unit, _, string] t_t
        method c_Var   _ _   s     = s
        method c_Const _ _   n     = string_of_int n
        method c_Binop _ _ _ s x y = "(" ^ (fself () x) ^ s ^ (fself () y) ^ ")"
      end

    class ['a] eval (fself: _ -> 'a t -> _) do_var =
      object
        inherit [ unit, 'a, int, unit, _, int] t_t
        method c_Var   _ _ x       = do_var x
        method c_Const _ _ n       = n
        method c_Binop _ _ f _ x y = f (fself () x) (fself () y)
      end

  end

let _ =
  let rec toString () e = transform0(Expr.t) (new Expr.toString toString) () e in
  let rec eval   s i e = transform0(Expr.t) (new Expr.eval (eval s) s) i e in
  let e = `Binop ((+), "+", `Const 1, `Var "a") in

  let s = toString () e in
  let v = eval (fun "a" -> 2) () e in
  Printf.printf "%s\n" s;
  Printf.printf "%d\n" v
