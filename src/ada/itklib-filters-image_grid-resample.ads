with Itklib.Images;
with Itklib.Process_Object;
with Itklib.Supported;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Image_Grid.Resample with SPARK_Mode => Off is
   pragma Compile_Time_Error
     (Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
      or else Input.Image_Dimension /= Output.Image_Dimension
      or else not Itklib.Supported.Resample
        (Input.Pixel_Kind_Id, Input.Image_Dimension),
      "Resample is not built for this pixel kind and dimension");

   --  itk::ResampleImageFilter with a linear interpolator and the identity
   --  transform. adaimg -resize uses this when the scale is not an integer
   --  shrink factor. Output size is round(input size * scale), at least 1,
   --  and spacing is divided by the same scale. Origin and direction are
   --  copied. The default pixel outside the input is 0.

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Output_Size (F : in out Filter; Extent : Input.Size);
   procedure Set_Output_Spacing (F : in out Filter; Value : Input.Vector);
   procedure Set_Output_Origin (F : in out Filter; Value : Input.Vector);
   procedure Set_Output_Direction (F : in out Filter; Value : Input.Direction);
   procedure Set_Default_Pixel (F : in out Filter; Value : Long_Float);
   --  Size and spacing are taken from the input when Update runs:
   --  output size = max (1, round (input size * Scale)) and
   --  output spacing = input spacing / Scale. Origin and direction are copied.
   procedure Set_Uniform_Scale (F : in out Filter; Scale : Long_Float);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with record
      Extent : Input.Size := [others => 0];
      Spacing : Input.Vector := [others => 1.0];
      Origin : Input.Vector := [others => 0.0];
      Direction : Input.Direction := [others => [others => 0.0]];
      Default_Pixel : Long_Float := 0.0;
   end record;
end Itklib.Filters.Image_Grid.Resample;
