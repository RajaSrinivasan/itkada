with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Img is new Itklib.Images (<>);
package Itklib.IO.Image_File_Writer with SPARK_Mode => Off is
   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_File_Name (F : in out Filter; Path : String);
   procedure Set_Input (F : in out Filter; Image : Img.Image);

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.IO.Image_File_Writer;
