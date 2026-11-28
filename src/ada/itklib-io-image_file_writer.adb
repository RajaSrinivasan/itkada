with Itklib.Supported;
with Itklib.Thin;

package body Itklib.IO.Image_File_Writer with SPARK_Mode => Off is

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Writer_New (Img.Pixel_Kind_Id, Img.Image_Dimension));
      end return;
   end Create;

   procedure Set_File_Name (F : in out Filter; Path : String) is
   begin
      Thin.Writer_Set_File (F.Raw_Handle, Path);
   end Set_File_Name;

   procedure Set_Input (F : in out Filter; Image : Img.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

begin
   if not Itklib.Supported.Image_Built (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation
        with "PNG writer is not built for this pixel kind and dimension";
   end if;
   if not Itklib.Supported.Png_Writer (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation
        with "PNG cannot store this pixel type; rescale or cast to an integer pixel before writing";
   end if;
   if not Thin.Is_Supported (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation
        with "Ada Supported and itklib_supported disagree";
   end if;
end Itklib.IO.Image_File_Writer;
