package Itklib.Core with SPARK_Mode => On is
   --  Hand-written Ada that does not call ITK. Region arithmetic and
   --  geometry live here so gnatprove can see them. Itklib.Thin and the
   --  generated filter packages stay SPARK_Mode Off.
end Itklib.Core;
