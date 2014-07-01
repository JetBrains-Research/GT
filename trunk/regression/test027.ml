open GT

@type ('a, 'b) t = {x: int; y: string; a: 'a; b: 'b} with show, map, eq, compare, foldl, foldr

class ['a, 'b] print =
  object 
    inherit ['a, unit, 'b, unit, unit, unit] @t
    method value _ _ x y a b = 
      Printf.printf "%d\n" x;
      Printf.printf "%s\n" y; 
      a.fx (); 
      b.fx ()
  end

let _ =
  let cs    = function EQ -> "EQ" | GT -> "GT" | LT -> "LT" in  
  let c x y = if x = y then EQ else if x < y then LT else GT in
  let x = {x=1; y="2"; a="a"; b=`B} in
  let y = {x=1; y="2"; a="3"; b=`B} in
  Printf.printf "x == x: %b\n" (transform(t) (rewrap_t (=)) (rewrap_t1 (=)) (new @eq[t]) (`t x) x);
  Printf.printf "x == y: %b\n" (transform(t) (rewrap_t (=)) (rewrap_t1 (=)) (new @eq[t]) (`t x) y);
  Printf.printf "compare (x, x) = %s\n" (cs (transform(t) (rewrap_t c) (rewrap_t1 c) (new @compare[t]) (`t x) x));
  Printf.printf "compare (x, y) = %s\n" (cs (transform(t) (rewrap_t c) (rewrap_t1 c) (new @compare[t]) (`t x) y));
  Printf.printf "compare (y, x) = %s\n" (cs (transform(t) (rewrap_t c) (rewrap_t1 c) (new @compare[t]) (`t y) x));
  Printf.printf "%s\n" 
    (transform(t) 
       (fun _ a -> string_of_int a) 
       (fun _ -> function `B -> "`B") 
       (new @show[t])
       ()
       (transform(t) (fun _ x -> int_of_string x) (fun _ x -> x) (new @map[t]) () y)
    );
  transform(t) 
    (fun _ a -> Printf.printf "%s\n" a) 
    (fun _ -> function `B -> Printf.printf "`B\n") 
    (new print) 
    () 
    x
