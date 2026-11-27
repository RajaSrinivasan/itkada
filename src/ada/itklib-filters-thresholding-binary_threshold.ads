with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Thresholding.Binary_Threshold with SPARK_Mode => Off is
   --  itk::BinaryThresholdImageFilter. A pixel is inside when it is
   --  between the lower and upper thresholds, inclusive. adaimg
   --  -threshold lo:hi uses inside 65535 and outside 0.

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Lower_Threshold (F : in out Filter; Value : Long_Float);
   procedure Set_Upper_Threshold (F : in out Filter; Value : Long_Float);
   procedure Set_Inside_Value (F : in out Filter; Value : Long_Float);
   procedure Set_Outside_Value (F : in out Filter; Value : Long_Float);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with record
      Lower : Long_Float := 0.0;
      Upper : Long_Float := 65_535.0;
      Inside_Value : Long_Float := 65_535.0;
      Outside_Value : Long_Float := 0.0;
   end record;
end Itklib.Filters.Thresholding.Binary_Threshold;
