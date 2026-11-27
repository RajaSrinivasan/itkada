with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Image_Gradient.Gradient_Magnitude with SPARK_Mode => Off is
   --  itk::GradientMagnitudeImageFilter with UInt16 output so the result
   --  can be written as PNG. Canny and other real-valued edge detectors
   --  wait for a generated float32 pixel type. adaimg -edge uses this
   --  filter and ITK's default UseImageSpacing (True).

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Use_Image_Spacing (F : in out Filter; Enabled : Boolean);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.Filters.Image_Gradient.Gradient_Magnitude;
