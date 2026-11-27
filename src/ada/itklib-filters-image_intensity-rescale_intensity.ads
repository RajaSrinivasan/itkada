with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Image_Intensity.Rescale_Intensity with SPARK_Mode => Off is
   --  itk::RescaleIntensityImageFilter. adaimg -rescale lo:hi sets the
   --  output minimum and maximum. Input min and max are taken from the
   --  image when Update runs.

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Output_Minimum (F : in out Filter; Value : Long_Float);
   procedure Set_Output_Maximum (F : in out Filter; Value : Long_Float);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with record
      Minimum : Long_Float := 0.0;
      Maximum : Long_Float := 65_535.0;
   end record;
end Itklib.Filters.Image_Intensity.Rescale_Intensity;
