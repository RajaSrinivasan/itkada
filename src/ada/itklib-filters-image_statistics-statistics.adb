with Itklib.Thin;

package body Itklib.Filters.Image_Statistics.Statistics with SPARK_Mode => Off is

   procedure Read (F : Filter; Minimum, Maximum, Mean : out Long_Float) is
   begin
      Thin.Statistics_Get (F.Raw_Handle, Minimum, Maximum, Mean);
   end Read;

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Statistics, Img.Pixel_Kind_Id, Img.Image_Dimension));
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Img.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   function Minimum (F : Filter) return Long_Float is
      Low, High, Average : Long_Float;
   begin
      Read (F, Low, High, Average);
      return Low;
   end Minimum;

   function Maximum (F : Filter) return Long_Float is
      Low, High, Average : Long_Float;
   begin
      Read (F, Low, High, Average);
      return High;
   end Maximum;

   function Mean (F : Filter) return Long_Float is
      Low, High, Average : Long_Float;
   begin
      Read (F, Low, High, Average);
      return Average;
   end Mean;

begin
   if not Thin.Is_Supported (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation with
        "Statistics is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Image_Statistics.Statistics;
