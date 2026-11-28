with Itklib.Images;
with Itklib.Process_Object;
with Itklib.Supported;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Smoothing.Median with SPARK_Mode => Off is
   pragma Compile_Time_Error
     (Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
      or else Input.Image_Dimension /= Output.Image_Dimension
      or else not Itklib.Supported.Median
        (Input.Pixel_Kind_Id, Input.Image_Dimension),
      "Median is not built for this pixel kind and dimension");

   --  itk::MedianImageFilter. Radius is the neighborhood radius on each
   --  axis (a radius of 1 is a 3-wide window). adaimg -median passes one
   --  radius to every axis.

   type Radius is array (Input.Axis) of Natural;

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Radius (F : in out Filter; Value : Radius);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.Filters.Smoothing.Median;
