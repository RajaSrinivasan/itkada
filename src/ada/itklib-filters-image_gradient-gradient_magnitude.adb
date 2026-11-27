with Itklib.Thin;

package body Itklib.Filters.Image_Gradient.Gradient_Magnitude with SPARK_Mode => Off is

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Gradient, Input.Pixel_Kind_Id, Input.Image_Dimension));
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Use_Image_Spacing (F : in out Filter; Enabled : Boolean) is
   begin
      Thin.Gradient_Set_Use_Image_Spacing (F.Raw_Handle, Enabled);
   end Set_Use_Image_Spacing;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "GradientMagnitude requires matching input and output images";
   end if;
   if not Thin.Is_Supported (Input.Pixel_Kind_Id, Input.Image_Dimension) then
      raise Unsupported_Instantiation with
        "GradientMagnitude is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Image_Gradient.Gradient_Magnitude;
