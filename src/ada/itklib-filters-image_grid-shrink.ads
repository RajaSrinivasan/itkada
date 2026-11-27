with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Image_Grid.Shrink with SPARK_Mode => Off is
   --  itk::ShrinkImageFilter. Output size on each axis is
   --  max (input size / factor, 1). Spacing is multiplied by the factor.
   --  adaimg -resize N% uses this when N < 100 and 100 is divisible by N
   --  (50% is factor 2).

   type Factors is array (Input.Axis) of Positive;

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Shrink_Factors (F : in out Filter; Value : Factors);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.Filters.Image_Grid.Shrink;
