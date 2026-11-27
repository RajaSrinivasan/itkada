with Interfaces;
with Itklib.Thin;

package body Itklib.Filters.Image_Grid.Shrink with SPARK_Mode => Off is

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Shrink, Input.Pixel_Kind_Id, Input.Image_Dimension));
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Shrink_Factors (F : in out Filter; Value : Factors) is
      Raw : Thin.Extent_Array (1 .. Input.Image_Dimension);
      K : Positive := 1;
   begin
      for Item of Value loop
         Raw (K) := Interfaces.Unsigned_64 (Item);
         K := K + 1;
      end loop;
      Thin.Shrink_Set_Factors (F.Raw_Handle, Raw);
   end Set_Shrink_Factors;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "Shrink requires matching input and output images";
   end if;
   if not Thin.Is_Supported (Input.Pixel_Kind_Id, Input.Image_Dimension) then
      raise Unsupported_Instantiation with
        "Shrink is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Image_Grid.Shrink;
