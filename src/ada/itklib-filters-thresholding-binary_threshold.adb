with Itklib.Thin;

package body Itklib.Filters.Thresholding.Binary_Threshold with SPARK_Mode => Off is

   procedure Push (F : Filter) is
   begin
      Thin.Threshold_Set
        (F.Raw_Handle, F.Lower, F.Upper, F.Inside_Value, F.Outside_Value);
   end Push;

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Threshold, Input.Pixel_Kind_Id, Input.Image_Dimension));
         Push (Result);
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Lower_Threshold (F : in out Filter; Value : Long_Float) is
   begin
      F.Lower := Value;
      Push (F);
   end Set_Lower_Threshold;

   procedure Set_Upper_Threshold (F : in out Filter; Value : Long_Float) is
   begin
      F.Upper := Value;
      Push (F);
   end Set_Upper_Threshold;

   procedure Set_Inside_Value (F : in out Filter; Value : Long_Float) is
   begin
      F.Inside_Value := Value;
      Push (F);
   end Set_Inside_Value;

   procedure Set_Outside_Value (F : in out Filter; Value : Long_Float) is
   begin
      F.Outside_Value := Value;
      Push (F);
   end Set_Outside_Value;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "BinaryThreshold requires matching input and output images";
   end if;
   if not Thin.Is_Supported (Input.Pixel_Kind_Id, Input.Image_Dimension) then
      raise Unsupported_Instantiation with
        "BinaryThreshold is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Thresholding.Binary_Threshold;
