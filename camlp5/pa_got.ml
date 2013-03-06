
(**************************************************************************
 *  Copyright (C) 2012
 *  Dmitri Boulytchev (dboulytchev@math.spbu.ru), St.Petersburg State University
 *  Universitetskii pr., 28, St.Petersburg, 198504, RUSSIA    
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 *
 *  See the GNU Lesser General Public License version 2.1 for more details
 *  (enclosed in the file COPYING).
 **************************************************************************)

(** 

  generic ('a, 'b, ..., 'z) t = [> `C1 of t1 | C2 of t2 | ... | Ck of tk ]
 
  let gmap ext ta tb ... tz t ihn s =
    let self = gmap m ext ta tb ... tz t in
    match s with
    | `C1 (x1, x2, ..., xk) -> ...
    | `C2 (x1, x2, ..., xk) -> ...

*)

#load "pa_extend.cmo";;
#load "q_MLast.cmo";;

open List
open Printf
open Pcaml
open MLast
open Ploc
     
let get_val (VaVal x) = x 

module S = Set.Make (String)

let name_generator list =
  let s = ref (fold_right S.add list S.empty) in
  object(self)
    method generate prompt =
      if S.mem prompt !s 
      then self#generate ("_" ^ prompt)
      else (
        s := S.add prompt !s;
        prompt
      )
  end

let cata  name  = name ^ "_gcata"
let others      = "others"
let cmethod c   = "m_" ^ c
let apply       = "apply"
    
EXTEND
  GLOBAL: str_item; 

  str_item: LEVEL "top" [
    [ "generic"; t=LIST1 t_decl SEP "and" -> 
      let t, d = split t in
      let get_cata =
        let s = fold_left (fun s (_, n, _) -> S.add n s) S.empty d in
        fun name -> 
          if S.mem name s then <:expr< $lid:cata name$ >> 
                          else let name, gcata = <:expr< $lid:name$ >>, <:expr< $lid:"gcata"$ >> in
                               <:expr< $name$ . $gcata$ >>
      in
      let g     = name_generator (map (fun (_, n, _) -> n) d) in
      let trans = g#generate "t"   in
      let ext   = g#generate "ext" in
      let farg  = 
        let module M = Map.Make (String) in
        let m = ref M.empty in
        (fun a -> 
           let p = "f" ^ a in
           try M.find p !m with
             Not_found -> 
               let n = g#generate p in
               m := M.add p n !m;
               n
        ) 
      in
      let subj = g#generate "s"   in
      let acc  = g#generate "acc" in
      let defs =
        map 
          (fun (args, name, descr) -> 
             let id x        = x in
             let of_lid name = <:expr< $lid:name$ >> in
             let make_call g f args =
               fold_left (fun e a -> <:expr< $e$ $g a$ >>) f args
             in
             let make_fun args body =
               fold_right 
                 (fun arg expr -> let a = <:patt< $lid:arg$ >> in <:expr< fun [ $list:[a, VaVal None, expr]$ ] >>)                  
                 args
                 body
             in
             let current    = name in
             let extensible, remove_bound_var, is_bound_var = 
               match descr with 
               | `Poly (`More x, _) -> true, filter (fun s -> s <> x), (fun s -> s = x)
               | _ -> false, (fun x -> x), (fun _ -> false)
             in
             let polyvar    = match descr with `Poly _ -> true | _ -> false in
             let args       = remove_bound_var args in
             let metargs    = (if extensible then [ext] else ["_"]) @ [trans] @ (map farg args) in
             let args       = metargs @ [acc; subj] in
             let get_type_handler, get_local_defs =
               let context = ref [] in
               (fun (args, qname) as typ ->
                  let args = match qname with [name] when name = current -> remove_bound_var args | _ -> args in
                  let name = 
                    try fst (assoc typ !context) with
                      Not_found ->
                        let compound_name = String.concat "_" (args @ qname) in
                        let apply = 
                          let g = <:expr< $uid:"Generic"$ >> in
                          let a = <:expr< $lid:apply$ >> in
                          <:expr< $g$ . $a$ >>
                        in
                        let base_gcata, ext = 
                          match qname with
                          | [name]      -> get_cata name, if name = current && extensible then <:expr< $lid:ext$ >> else apply
                          | name::names -> 
                              let base = 
                                fold_left (fun q name -> 
                                             let name = if Char.lowercase name.[0] = name.[0] 
                                                        then <:expr< $lid:name$ >>
                                                        else <:expr< $uid:name$ >>
                                             in
                                             <:expr< $q$ . $name$ >>   
                                          ) 
                                          <:expr< $uid:name$ >> 
                                          names
                              in
                              let fname = <:expr< $uid:"Generic"$ >> in
                              let fname = <:expr< $fname$ . $lid:"gcata"$ >> in
                              <:expr< $base$ . $fname$ >>, apply
                        in
                        let impl =
                          (
                           <:patt< $lid:compound_name$ >>, 
                           make_fun 
                             [acc; subj] 
                             (make_call id base_gcata (ext :: map of_lid ([trans] @ (map farg args) @ [acc; subj])))
                          )
                        in
                        let name = <:expr< $lid:compound_name$ >> in
                        context := (typ, (name, impl)) :: !context;
                        name
                  in
                  name
               ),
               (fun () ->
                  map (fun (_, (_, x)) -> x) !context
               )
             in
             let match_cases =
               map 
                 (fun (cname, cargs) -> 
                    let args, _ = fold_right (fun arg (acc, n) -> (sprintf "p%d" n) :: acc, n+1) cargs ([], 1) in
                    let args    = rev args in
                    let patt    =
                      fold_left 
                        (fun p id -> let pid = <:patt< $lid:id$ >> in <:patt< $p$ $pid$ >>)
                        (if polyvar then <:patt< ` $cname$ >> else <:patt< $uid:cname$ >>) 
                        args
                    in
                    let expr =
                      let obj = <:expr< $lid:trans$ >> in
                      let met = <:expr< $obj$ # $cmethod cname$ >> in
                      let garg f x =
                        let g = <:expr< $uid:"Generic"$ >> in
                        let m = <:expr< $lid:"make"$ >> in
                        let gm = <:expr< $g$ . $m$ >> in
                        make_call id gm [f; x]
                      in
                      make_call id 
                        met 
                        (<:expr< $lid:acc$  >> :: 
                         <:expr< $lid:subj$ >> :: 
                         (map (fun (typ, x) -> 
                                 match typ with
                                 | `Protected _   -> <:expr< $lid:x$ >>
                                 | `Variable name -> garg <:expr< $lid:farg name$ >> <:expr< $lid:x$ >>
                                 | `Processing t   -> 
                                     let name = get_type_handler t in 
                                     garg name <:expr< $lid:x$ >>
                              ) 
                              (combine cargs args)
                         )
                        )
                    in
                    patt, VaVal None, expr
                 ) 
                 (match descr with `Vari cons | `Poly (_, cons) -> cons)
             in
             let match_cases = 
               if extensible then match_cases @ [<:patt< $lid:others$ >>, 
                                                 VaVal None,
                                                 make_call of_lid <:expr< $lid:ext$ >> ["self"; acc; others]
                                                ]
                             else match_cases
             in
             let subj = <:expr< $lid:subj$ >> in 
             let local_defs_and_then expr =
               let local_defs =
                  get_local_defs () @
                  if extensible then [<:patt< $lid:"self"$ >>, make_call of_lid <:expr< $lid:cata current$ >> metargs]
                                else []
               in
               match local_defs with
               | [] -> expr
               | _  -> <:expr< let $list:local_defs$ in $expr$ >>
             in
             <:patt< $lid:cata name$ >>, 
             (make_fun args (local_defs_and_then <:expr< match $subj$ with [ $list:match_cases$ ] >>))
          ) 
          d
      in
      let generic_cata = 
        let g = <:patt< $uid:"Generic"$ >> in
        let c = <:patt< $lid:"gcata"$ >> in
        <:patt< $g$ . $c$ >>
      in
      let pnames, tnames = 
        split (
          map (fun (_, name, _) -> 
                 let pe = [generic_cata, <:expr< $lid:cata name$ >>] in 
                 <:patt< $lid:name$ >>, <:expr< { $list:pe$ } >>
              ) 
              d
        ) 
      in
      let tuple = <:patt< ( $list:pnames$ ) >> in
      let tup = <:expr< ( $list:tnames$ ) >> in 
      let def = <:expr< let rec $list:defs$ in $tup$ >> in
      let cata_def = <:str_item< value $list:[tuple, def]$ >> in
      let type_def = <:str_item< type $list:t$ >> in
      <:str_item< declare $list:[type_def; cata_def]$ end >> ]
  ];

  t_decl: [
    [ a=fargs; n=LIDENT; "="; t=rhs ->      
      let args, (def, cons) = a, fst t in
      {
        tdNam = VaVal (loc, VaVal n);
        tdPrm = VaVal (map (fun name -> VaVal (Some name), None) args);
        tdPrv = VaVal false;
        tdDef = def; 
        tdCon = VaVal cons
      },
      (a, n, snd t)
    ]
  ];

  rhs: [[ vari ] | [ poly ]];

  vari: [
    [ OPT "|"; vari_cons=LIST1 vari_con SEP "|" -> 
        let x, y = split vari_cons in
        (<:ctyp< [ $list:x$ ] >>, []), `Vari y
    ]
  ];

  vari_con: [
    [ c=UIDENT; a=con_args -> (loc, VaVal c, fst a, None), (c, snd a) ]
  ];

  poly: [
    [ "["; body=poly_body; "]" -> 
        let lcons, y = body in
        (<:ctyp< [ = $list:lcons$ ] >>, []), `Poly (`Equal, y) 
    ] |
    [ a=targ; "constraint"; "["; ">"; body=poly_body; "]" ->
        let lcons, y = body in
        (<:ctyp< ' $a$ >>, [<:ctyp< ' $a$ >>, <:ctyp< [ > $list:lcons$ ] >>]), `Poly (`More a, y)
    ]
  ];

  poly_body: [
    [ OPT "|"; poly_cons=LIST1 poly_con SEP "|" ->
        let x, y = split poly_cons in
        let lcons = map (fun (loc, name, args, _) ->                                  
	    	    	     	 if length args = 0 
                                 then <:poly_variant< `$name$ >>         
                                 else                          
                                   let args = [<:ctyp< ($list:args$) >>] in
                                   <:poly_variant< `$name$ of $flag:false$ $list:args$ >> 
                              ) x
        in
        lcons, y
    ]
  ];

  poly_con: [
    [ "`"; c=UIDENT; a=con_args -> (loc, c, get_val (fst a), None), (c, snd a) ]
  ];

  con_args: [
    [ "of"; a=LIST1 typ SEP "*" -> let x, y = split a in VaVal x, y ] |
    [ -> VaVal [], [] ]
  ];

  typ: [ 
    [ "["; t=ctyp; "]" -> t, `Protected t ] |
    [ c_typ ]
  ];

  c_typ: [
    [ a=targ; q=OPT qname -> 
       let at = <:ctyp< ' $a$ >> in
       match q with 
       | Some q -> <:ctyp< $fst q$ $at$ >>, `Processing ([a], snd q)
       | None -> <:ctyp< ' $a$ >>, `Variable a
    ] | 
    [ "("; a=LIST1 targ SEP ","; ")"; q=qname -> 
       fold_left (fun acc a -> let at = <:ctyp< ' $a$ >> in <:ctyp< $acc$ $at$ >>) (fst q) a, 
       `Processing (a, snd q) 
    ] |
    [ q=qname -> fst q, `Processing ([], snd q) ]
  ];

  qname: [
    [ x=LIDENT -> <:ctyp< $lid:x$ >>, [x] ] |
    [ q=UIDENT; "."; n=qname -> 
       let t = <:ctyp< $uid:q$ >> in 
       <:ctyp< $t$ . $fst n$ >>, q :: snd n
    ]
  ];

  fargs: [
    [ a=targ -> [a] ] |
    [ "("; a=LIST1 targ SEP ","; ")" -> a ] |
    [ -> [] ]
  ];

  targ: [
    [ "'"; a=LIDENT -> a ]
  ];
  
END;