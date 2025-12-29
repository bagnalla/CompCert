(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(* Generic branch relaxation over target-specific instruction sets. *)

open Asm
open Maps

module type TARGET = sig
  type instruction

  (* Conservative size estimate for layout. *)
  val instr_size : instruction -> int
  (* Recognize label instructions for position mapping. *)
  val is_label : instruction -> label option
  (* True when control can flow to the next instruction. *)
  val instr_fall_through : instruction -> bool
  (* Mark relaxation labels to guide alignment decisions. *)
  val relax_tbl : instruction list -> bool PTree.t
  (* Apply alignment before this instruction and return the new position. *)
  val align_before :
    fallthrough:bool -> relax_tbl:bool PTree.t -> pos:int -> instruction -> int

  (* Return branch target, range, and a relaxer that takes a fresh label. *)
  val branch_info :
    instruction -> (label * int * (label -> instruction list)) option

  (* Provide fresh labels for relaxation sequences. *)
  val new_label : unit -> label
end

module Make (T: TARGET) = struct
  let label_positions (relax_tbl: bool PTree.t)
                      (code: T.instruction list) : int PTree.t =
    let rec go tbl pos fallthrough = function
      | [] -> tbl
      | i :: rest ->
          let pos = T.align_before ~fallthrough ~relax_tbl ~pos i in
          let tbl' =
            match T.is_label i with
            | None -> tbl
            | Some lbl -> PTree.set lbl pos tbl
          in
          let pos' = pos + T.instr_size i in
          let fallthrough' = T.instr_fall_through i in
          go tbl' pos' fallthrough' rest
    in
    go PTree.Empty 0 true code

  let relax_once (code: T.instruction list) : T.instruction list * bool =
    let relax_tbl = T.relax_tbl code in
    let lbl_pos = label_positions relax_tbl code in
    let changed = ref false in
    let rec go pos fallthrough acc = function
      | [] -> (List.rev acc, !changed)
      | i :: rest ->
          let pos = T.align_before ~fallthrough ~relax_tbl ~pos i in
          begin match T.branch_info i with
          | None ->
              let pos' = pos + T.instr_size i in
              let fallthrough' = T.instr_fall_through i in
              go pos' fallthrough' (i :: acc) rest
          | Some (tgt, range, relaxer) ->
              let tgt_pos =
                match PTree.get tgt lbl_pos with
                | Some p -> p
                | None -> assert false
              in
              let disp = tgt_pos - pos in
              if disp < -range || range <= disp then begin
                changed := true;
                let lbl = T.new_label () in
                let repl = relaxer lbl in
                let pos' = pos + T.instr_size i in
                let fallthrough' = T.instr_fall_through i in
                go pos' fallthrough' (List.rev_append repl acc) rest
              end else
                let pos' = pos + T.instr_size i in
                let fallthrough' = T.instr_fall_through i in
                go pos' fallthrough' (i :: acc) rest
          end
    in
    go 0 true [] code

  let rec relax_fixpoint (code: T.instruction list) : T.instruction list =
    let code', changed = relax_once code in
    if changed then relax_fixpoint code' else code'
end
