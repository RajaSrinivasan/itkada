with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Img is new Itklib.Images (<>);
package Itklib.IO.Image_File_Reader with SPARK_Mode => Off is
   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_File_Name (F : in out Filter; Path : String);
   function Get_Output (F : Filter) return Img.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.IO.Image_File_Reader;
