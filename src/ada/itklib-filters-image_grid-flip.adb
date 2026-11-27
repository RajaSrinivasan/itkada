with Itklib.Thin;

package body Itklib.Filters.Image_Grid.Flip with SPARK_Mode => Off is

   procedure Push (F : Filter) is
      Raw : Thin.Extent_Array (1 .. Img.Image_Dimension);
      K : Positive := 1;
   begin
      for Flag of F.Axes loop
         if Flag then
            Raw (K) := 1;
         else
            Raw (K) := 0;
         end if;
         K := K + 1;
      end loop;
      Thin.Flip_Set_Axes (F.Raw_Handle, Raw, F.About_Origin);
   end Push;

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New (Thin.Flip, Img.Pixel_Kind_Id, Img.Image_Dimension));
         Push (Result);
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Img.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Flip_Axes (F : in out Filter; Axes : Axis_Flags) is
   begin
      F.Axes := Axes;
      Push (F);
   end Set_Flip_Axes;

   procedure Set_Flip_About_Origin (F : in out Filter; Enabled : Boolean) is
   begin
      F.About_Origin := Enabled;
      Push (F);
   end Set_Flip_About_Origin;

   function Get_Output (F : Filter) return Img.Image is
   begin
      return Img.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if not Thin.Is_Supported (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation with
        "Flip is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Image_Grid.Flip;
