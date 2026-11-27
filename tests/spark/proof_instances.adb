package body Proof_Instances with SPARK_Mode => On is
   procedure Ignore_2 (Idx : D2.Index; Off : Interfaces.Unsigned_64) is
      pragma Unreferenced (Idx, Off);
   begin
      null;
   end Ignore_2;

   procedure Ignore_3 (Idx : D3.Index; Off : Interfaces.Unsigned_64) is
      pragma Unreferenced (Idx, Off);
   begin
      null;
   end Ignore_3;
end Proof_Instances;
