package Itklib with SPARK_Mode => On is
   --  Every ITK scalar is named here. Phase 0 builds UInt16 only.

   type Pixel_Kind is
     (UInt8, Int8, UInt16, Int16, UInt32, Int32, UInt64, Int64, Float32,
      Float64);

   function Bits_Of (Kind : Pixel_Kind) return Natural is
     (case Kind is
         when UInt8 | Int8 => 8,
         when UInt16 | Int16 => 16,
         when UInt32 | Int32 | Float32 => 32,
         when UInt64 | Int64 | Float64 => 64)
   with Post => Bits_Of'Result in 8 | 16 | 32 | 64, Global => null;

   Itk_Error, Unsupported_Instantiation : exception;

   --  Linked ITK version, for example "5.4.8". Not SPARK: it calls C.
   function ITK_Version return String with SPARK_Mode => Off;

   --  ITK objects created by the shim and not yet destroyed.
   function Debug_Live_Objects return Natural with SPARK_Mode => Off;

   --  Ada handle wrappers still alive. Drops to the baseline when the
   --  last controlled object is finalized.
   function Debug_Live_Wrappers return Natural with SPARK_Mode => Off;

   --  One ITK pipeline must not be shared across Ada tasks without a
   --  protected wrapper. ITK may still multithread inside Update.
end Itklib;
