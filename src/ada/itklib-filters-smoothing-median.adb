with Interfaces;
with Itklib.Thin;

package body Itklib.Filters.Smoothing.Median with SPARK_Mode => Off is

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Median, Input.Pixel_Kind_Id, Input.Image_Dimension));
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Radius (F : in out Filter; Value : Radius) is
      Raw : Thin.Extent_Array (1 .. Input.Image_Dimension);
      K : Positive := 1;
   begin
      for Item of Value loop
         Raw (K) := Interfaces.Unsigned_64 (Item);
         K := K + 1;
      end loop;
      Thin.Median_Set_Radius (F.Raw_Handle, Raw);
   end Set_Radius;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "Median requires matching input and output images";
   end if;
   if not Itklib.Supported.Agrees
     (Itklib.Supported.Median, Input.Pixel_Kind_Id, Input.Pixel_Kind_Id,
      Input.Image_Dimension)
   then
      raise Unsupported_Instantiation with
        "Median Ada support and the C table disagree";
   end if;
end Itklib.Filters.Smoothing.Median;
