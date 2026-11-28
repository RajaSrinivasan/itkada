with Itklib.Images;
with Itklib.Process_Object;
with Itklib.Supported;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Image_Grid.Extract with SPARK_Mode => Off is
   pragma Compile_Time_Error
     (Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
      or else Input.Image_Dimension /= Output.Image_Dimension
      or else not Itklib.Supported.Extract
        (Input.Pixel_Kind_Id, Input.Image_Dimension),
      "Extract is not built for this pixel kind and dimension");

   --  itk::ExtractImageFilter with the same input and output dimension,
   --  so the crop stays in-plane (a size of 1 does not drop an axis).
   --  Direction collapse is set to submatrix for the equal-dimension case,
   --  which ITK does not consult. adaimg -crop WxH+X+Y maps W,H to size and
   --  X,Y to the region index. The index origin is 0, matching ITK.
   --  A region outside the input becomes Itk_Error when Update runs.

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Extraction_Region (F : in out Filter; Value : Input.Region);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with record
      Known_Input : Boolean := False;
      Input_Region : Input.Region :=
        (Start => [others => 0], Extent => [others => 0]);
   end record;
end Itklib.Filters.Image_Grid.Extract;
