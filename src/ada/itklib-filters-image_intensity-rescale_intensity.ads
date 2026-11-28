with Itklib.Images;
with Itklib.Process_Object;
with Itklib.Supported;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Image_Intensity.Rescale_Intensity with SPARK_Mode => Off is
   pragma Compile_Time_Error
     (Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
      or else Input.Image_Dimension /= Output.Image_Dimension
      or else not Itklib.Supported.RescaleIntensity
        (Input.Pixel_Kind_Id, Input.Image_Dimension),
      "RescaleIntensity is not built for this pixel kind and dimension");

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
