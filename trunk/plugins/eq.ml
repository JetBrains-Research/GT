#load "q_MLast.cmo";;

open Pa_gt.Plugin
open List
open Printf
open MLast
open Ploc 

exception Found of int

let _ =
  register "eq" 
    (fun loc d -> 
       let module H = Helper (struct let loc = loc end) in       
       H.(
        let proper_args, inh_t =
	  if d.is_polyvar 
	  then
            let ng   = name_generator d.type_args in
            let self = ng#generate "self" in
	    let args = self :: d.type_args in
	    args,
	    `Poly (T.app (T.id (type_open_t d.name) :: map T.var args), fun x -> T.var x)
	  else
	    d.type_args,
	    `Poly (T.app (T.id d.name :: map T.var d.type_args), fun x -> T.var x)
	in        
        {
          inh_t       = inh_t;
          syn_t       = T.id "bool";
          proper_args = proper_args;
          arg_img     = (fun _ -> T.id "bool")
        }, 
        object
	  inherit generator
	  method record env fields = invalid_arg "not supported"
	  method tuple env elems = invalid_arg "not supported"
	  method constructor env name cargs =
	    let gen    = name_generator (map fst cargs) in
	    let args   = map (fun a -> a, gen#generate a) (map fst cargs) in
	    let arg  a = assoc a args in
	    let branch = 
	      fold_left
		(fun acc (b, typ) ->
		  E.app [E.lid "&&";
			 acc;
			 match typ with
			 | Instance (_, args, qname) ->
			     (match env.trait "eq" typ with
			     | None   -> E.uid "true"
			     | Some e -> 
				 let rec name = function
				 | [n] -> E.app [e; E.app [E.variant type_tag; E.id (arg b)]; E.id b]
				 | _::t -> name t
				 in
				 name qname
			     )
			 | Variable (_, a) -> E.app [E.gt_fx (E.id b); E.app [E.variant (d.arg_tag a); E.id (arg b)]]
			 | Self     _      -> E.app [E.gt_fx (E.id b); E.app [E.variant type_tag; E.id (arg b)]]
			 | Arbitrary _     -> E.uid "true"
		       ]
		)
		(E.uid "true")
		cargs
	    in
	    E.match_e (E.id env.inh) 
              [P.app [P.variant type_tag;
                      P.app (((if d.is_polyvar then P.variant else P.uid) name)::(map (fun (_, a) -> P.id a) args))
                     ], VaVal None, branch; 
               P.wildcard, VaVal None, E.uid "false"
              ]
	end
       )
    )