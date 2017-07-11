open Printf

type 'a logic = Value of 'a | Var of int
(* [@@deriving gt { showT } ] *)

let rec logic_meta_gcata fa tpo trans initial_inh subj =
  let self = logic_meta_gcata fa tpo trans  in
  match subj with
  | Value p0 -> trans#c_Value initial_inh (GT.make self subj tpo) (fa p0)
  | Var p0 -> trans#c_Var initial_inh (GT.make self subj tpo) p0
let logic_gcata fa transformer initial_inh subj =
  let parameter_transforms_obj = object method a = fa end  in
  logic_meta_gcata (fun x  -> GT.make fa x parameter_transforms_obj)
    parameter_transforms_obj transformer initial_inh subj

class type virtual
  ['inh,'syn,'tpoT,'type_itself,'gt_a_for_self,'gt_a_for_a] logic_meta_tt =
  object
    method  virtual c_Value :
      'inh -> ('inh,'type_itself,'syn,'tpoT) GT.a -> 'gt_a_for_a -> 'syn
    method  virtual c_Var :
      'inh -> ('inh,'type_itself,'syn,'tpoT) GT.a -> int -> 'syn
  end
class virtual
  ['inh,'syn,'tpoT,'type_itself,'gt_a_for_self,'gt_a_for_a] logic_meta_t =
  object (self : 'self)
    constraint 'self =
      ('inh,'syn,'tpoT,'type_itself,'gt_a_for_self,'gt_a_for_a)#logic_meta_tt
  end
class virtual ['inh,'syn,'tpoT,'a,'ia,'sa,'gt_a_for_a] logic_t =
  object (this)
    inherit  ['inh,'syn,'tpoT,'a logic,'a logic,'gt_a_for_a] logic_meta_t
  end

class ['tpoT,'a,'a_holder,'self_holder] showF_meta_logic
  (for_a: Format.formatter -> 'a_holder -> unit)
  (for_me: Format.formatter -> 'self_holder -> unit) =
  object (this)
    inherit  [Format.formatter,unit,'tpoT, 'a,Format.formatter,unit,'a_holder] logic_t
    method c_Var fmt subj p0 =
      Format.fprintf fmt "Var (%s)" ((GT.lift (GT.int.GT.plugins)#show ()) p0)
    method c_Value fmt subj (p0 : 'a_holder) =
      Format.fprintf fmt "Value (%a)" for_a   p0
  end
class ['a] showF_logic for_me =
  object
    inherit
      [ < a: Format.formatter -> 'a -> unit >  as 'tpoT
      , 'a, (Format.formatter,'a,unit,'tpoT) GT.a
      ,'a logic]
      showF_meta_logic (fun fmt pa -> pa.GT.fx fmt) for_me
  end
let logic =
  { GT.gcata = logic_gcata
  ; GT.plugins = object (self)
        method showF fa fmt subj =
          logic_gcata fa (new showF_logic (self#showF fa)) fmt subj
      end
  }

(* let (_:int) = logic.GT.plugins#showF *)

let () =
  let rec showF fa fmt xs = logic.GT.plugins#showF fa fmt xs in
  (* let (_:int) = showF (fun fmt -> Format.fprintf fmt "%s") in *)
  Format.fprintf Format.std_formatter "%a@;@?" (showF (fun fmt -> Format.fprintf fmt "%d")) (Var 5);
  Format.fprintf Format.std_formatter "%a@;@?" (showF (fun fmt -> Format.fprintf fmt "%s")) (Value "asdf");
  (* printf "%s\n%!" (show string_of_int (Cons (2, Cons (2, Nil)))); *)
  ()
