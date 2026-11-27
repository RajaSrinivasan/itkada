with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Itklib.IO.Image_File_Reader;
with Itklib.IO.Image_File_Writer;
with Itklib.Images;
with Itklib.Pixels.UInt16;

procedure Adaimg is
   --  Phase 0 copy: adaimg in.png out.png
   --  Built only on the Ada API. Update on the writer pulls the reader.

   package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
   package Reader is new Itklib.IO.Image_File_Reader (Img);
   package Writer is new Itklib.IO.Image_File_Writer (Img);

begin
   if Ada.Command_Line.Argument_Count /= 2 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: adaimg in.png out.png");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Input : Reader.Filter := Reader.Create;
      Output : Writer.Filter := Writer.Create;
   begin
      Input.Set_File_Name (Ada.Command_Line.Argument (1));
      Output.Set_Input (Input.Get_Output);
      Output.Set_File_Name (Ada.Command_Line.Argument (2));
      Output.Update;
   end;
exception
   when Event : Itklib.Itk_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (Event));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Adaimg;
