with Itklib.Supported;
with Itklib.Thin;

package body Itklib.IO.Image_File_Reader with SPARK_Mode => Off is

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Reader_New (Img.Pixel_Kind_Id, Img.Image_Dimension));
      end return;
   end Create;

   procedure Set_File_Name (F : in out Filter; Path : String) is
   begin
      Thin.Reader_Set_File (F.Raw_Handle, Path);
   end Set_File_Name;

   function Get_Output (F : Filter) return Img.Image is
   begin
      return Img.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if not Itklib.Supported.Image_Built (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation
        with "PNG reader is not built for this pixel kind and dimension";
   end if;
   if not Thin.Is_Supported (Img.Pixel_Kind_Id, Img.Image_Dimension) then
      raise Unsupported_Instantiation
        with "Ada Supported and itklib_supported disagree";
   end if;
end Itklib.IO.Image_File_Reader;
