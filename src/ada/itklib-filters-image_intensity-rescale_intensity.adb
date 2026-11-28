with Itklib.Thin;

package body Itklib.Filters.Image_Intensity.Rescale_Intensity with SPARK_Mode => Off is

   procedure Push (F : Filter) is
   begin
      Thin.Rescale_Set_Output_Range (F.Raw_Handle, F.Minimum, F.Maximum);
   end Push;

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Rescale, Input.Pixel_Kind_Id, Input.Image_Dimension));
         Push (Result);
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Output_Minimum (F : in out Filter; Value : Long_Float) is
   begin
      F.Minimum := Value;
      Push (F);
   end Set_Output_Minimum;

   procedure Set_Output_Maximum (F : in out Filter; Value : Long_Float) is
   begin
      F.Maximum := Value;
      Push (F);
   end Set_Output_Maximum;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "RescaleIntensity requires matching input and output images";
   end if;
   if not Itklib.Supported.Agrees
     (Itklib.Supported.RescaleIntensity, Input.Pixel_Kind_Id, Input.Pixel_Kind_Id,
      Input.Image_Dimension)
   then
      raise Unsupported_Instantiation with
        "RescaleIntensity Ada support and the C table disagree";
   end if;
end Itklib.Filters.Image_Intensity.Rescale_Intensity;
