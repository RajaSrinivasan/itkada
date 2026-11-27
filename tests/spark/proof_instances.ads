with Interfaces;
with Itklib.Core.Regions;
with Itklib.Pixel_Signature;

package Proof_Instances with SPARK_Mode => On is
   package U16 is new Itklib.Pixel_Signature
     (Interfaces.Unsigned_16, Itklib.UInt16);

   package D2 is new Itklib.Core.Regions (2);
   package D3 is new Itklib.Core.Regions (3);

   procedure Ignore_2 (Idx : D2.Index; Off : Interfaces.Unsigned_64) with
     Global => null;
   procedure Ignore_3 (Idx : D3.Index; Off : Interfaces.Unsigned_64) with
     Global => null;

   procedure Walk_2 is new D2.Walk (Ignore_2);
   procedure Walk_3 is new D3.Walk (Ignore_3);
end Proof_Instances;
