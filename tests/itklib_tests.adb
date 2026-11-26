with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;
with Interfaces;
with Itklib.Filters.Smoothing.Discrete_Gaussian;
with Itklib.IO.Image_File_Reader;
with Itklib.IO.Image_File_Writer;
with Itklib.Images;
with Itklib.Pixel_Signature;
with Itklib.Pixels.UInt16;

procedure Itklib_Tests is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Itklib.Pixel_Kind;
   package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
   package Vol is new Itklib.Images (Itklib.Pixels.UInt16, 3);
   package Reader is new Itklib.IO.Image_File_Reader (Img);
   package Writer is new Itklib.IO.Image_File_Writer (Img);
   package Smooth is new Itklib.Filters.Smoothing.Discrete_Gaussian (Img, Img);
   package Smooth3 is new Itklib.Filters.Smoothing.Discrete_Gaussian (Vol, Vol);

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line ("FAIL: " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Fill_2D (Image : in out Img.Image; Width : Interfaces.Unsigned_64) is
      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for K in Data'Range loop
            declare
               X : constant Natural := Natural (K mod Width);
               Y : constant Natural := Natural (K / Width);
               Value : Interfaces.Unsigned_16;
            begin
               case X mod 8 is
                  when 0 =>
                     Value := 0;
                  when 1 =>
                     Value := 1;
                  when 2 =>
                     Value := 255;
                  when 3 =>
                     Value := 256;
                  when 4 =>
                     Value := 1_000;
                  when 5 =>
                     Value := 32_767;
                  when 6 =>
                     Value := 32_768;
                  when others =>
                     Value := 65_535;
               end case;
               if Y > 0 then
                  Value :=
                    Interfaces.Unsigned_16
                      ((Interfaces.Unsigned_32 (Value) / 2) +
                       Interfaces.Unsigned_32 (Y));
               end if;
               Data (K) := Value;
            end;
         end loop;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Image);
   end Fill_2D;

   function Same_Pixels (Left, Right : in out Img.Image) return Boolean is
      Match : Boolean := True;

      procedure Read_Left (Data : in out Img.Pixel_Array) is
         procedure Read_Right (Other : in out Img.Pixel_Array) is
         begin
            if Data'Length /= Other'Length then
               Match := False;
               return;
            end if;
            for K in Data'Range loop
               if Data (K) /= Other (K - Data'First + Other'First) then
                  Match := False;
                  return;
               end if;
            end loop;
         end Read_Right;

         procedure Apply_Right is new Img.With_Buffer (Read_Right);
      begin
         Apply_Right (Right);
      end Read_Left;

      procedure Apply_Left is new Img.With_Buffer (Read_Left);
   begin
      Apply_Left (Left);
      return Match;
   end Same_Pixels;

   function Region_Matches (Image : Img.Image; Width, Height : Natural) return Boolean
   is
      Region : constant Img.Region := Img.Largest_Possible_Region (Image);
   begin
      return
        Region.Extent (1) = Interfaces.Unsigned_64 (Width)
        and then Region.Extent (2) = Interfaces.Unsigned_64 (Height)
        and then Region.Start (1) = 0
        and then Region.Start (2) = 0;
   end Region_Matches;

   procedure Test_Signature is
   begin
      Check (Img.Pixel'Size = 16, "UInt16 pixel is 16 bits");
      Check (Img.Pixel_Kind_Id = Itklib.UInt16, "signature kind");
      Check (Itklib.ITK_Version'Length > 0, "ITK version string");
      Check
        (Itklib.ITK_Version (Itklib.ITK_Version'First) = '5', "ITK major version 5");
   end Test_Signature;

   procedure Test_Lifetime_And_Buffer is
      Baseline_Objects : constant Natural := Itklib.Debug_Live_Objects;
      Baseline_Wrappers : constant Natural := Itklib.Debug_Live_Wrappers;
   begin
      declare
         Image : Img.Image := Img.Create ((4, 5));
         Before : Natural;
      begin
         Check (Itklib.Debug_Live_Objects = Baseline_Objects + 1, "image armed");
         Check
           (Itklib.Debug_Live_Wrappers = Baseline_Wrappers + 1, "one wrapper");
         Check (Region_Matches (Image, 4, 5), "2D region");
         Before := Img.Reference_Count (Image);
         declare
            Copy : Img.Image := Image;
         begin
            Check
              (Img.Reference_Count (Image) = Before + 1, "copy registers");
            Check
              (Img.Reference_Count (Copy) = Img.Reference_Count (Image),
               "copies share the count");
            Fill_2D (Image, 4);
            Check (Same_Pixels (Image, Copy), "copies share the buffer");
         end;
         Check (Img.Reference_Count (Image) = Before, "finalize unregisters");
         Check
           (Itklib.Debug_Live_Wrappers = Baseline_Wrappers + 1,
            "copy released the wrapper ref only");
      end;
      Check
        (Itklib.Debug_Live_Objects = Baseline_Objects, "last finalize destroys");
      Check
        (Itklib.Debug_Live_Wrappers = Baseline_Wrappers, "wrapper freed");
   end Test_Lifetime_And_Buffer;

   procedure Test_3D is
      Volume : Vol.Image := Vol.Create ((3, 4, 5));
      Region : constant Vol.Region := Vol.Largest_Possible_Region (Volume);
      Seen : Boolean := False;

      procedure Write (Data : in out Vol.Pixel_Array) is
         SX : constant Interfaces.Unsigned_64 := 3;
         SY : constant Interfaces.Unsigned_64 := 4;
      begin
         Check (Data'Length = 60, "3D buffer length");
         for Z in 0 .. 4 loop
            for Y in 0 .. 3 loop
               for X in 0 .. 2 loop
                  declare
                     Offset : constant Interfaces.Unsigned_64 :=
                       Interfaces.Unsigned_64 (X) +
                       Interfaces.Unsigned_64 (Y) * SX +
                       Interfaces.Unsigned_64 (Z) * SX * SY;
                     Value : constant Interfaces.Unsigned_16 :=
                       Interfaces.Unsigned_16 (X + 10 * Y + 100 * Z);
                  begin
                     Data (Offset) := Value;
                  end;
               end loop;
            end loop;
         end loop;
      end Write;

      procedure Read (Data : in out Vol.Pixel_Array) is
         SX : constant Interfaces.Unsigned_64 := 3;
         SY : constant Interfaces.Unsigned_64 := 4;
      begin
         Seen := True;
         for Z in 0 .. 4 loop
            for Y in 0 .. 3 loop
               for X in 0 .. 2 loop
                  declare
                     Offset : constant Interfaces.Unsigned_64 :=
                       Interfaces.Unsigned_64 (X) +
                       Interfaces.Unsigned_64 (Y) * SX +
                       Interfaces.Unsigned_64 (Z) * SX * SY;
                  begin
                     Check
                       (Data (Offset) =
                          Interfaces.Unsigned_16 (X + 10 * Y + 100 * Z),
                        "3D pixel");
                  end;
               end loop;
            end loop;
         end loop;
      end Read;

      procedure Apply_Write is new Vol.With_Buffer (Write);
      procedure Apply_Read is new Vol.With_Buffer (Read);
   begin
      Check
        (Region.Extent (1) = 3 and then Region.Extent (2) = 4
         and then Region.Extent (3) = 5,
         "3D region");
      Apply_Write (Volume);
      Apply_Read (Volume);
      Check (Seen, "3D buffer visited");
   end Test_3D;

   procedure Test_Geometry is
      Image : Img.Image := Img.Create ((2, 2));
   begin
      Image.Set_Spacing ((0.5, 2.0));
      Image.Set_Origin ((1.0, -4.0));
      Image.Set_Direction (((0.0, -1.0), (1.0, 0.0)));
      declare
         Space : constant Img.Vector := Image.Spacing;
         Start : constant Img.Vector := Image.Origin;
         Matrix : constant Img.Direction := Image.Image_Direction;
      begin
         Check (Space (1) = 0.5 and then Space (2) = 2.0, "spacing");
         Check (Start (1) = 1.0 and then Start (2) = -4.0, "origin");
         Check (Matrix (1, 1) = 0.0 and then Matrix (1, 2) = -1.0, "direction row 1");
         Check (Matrix (2, 1) = 1.0 and then Matrix (2, 2) = 0.0, "direction row 2");
      end;
   end Test_Geometry;

   procedure Test_Png (Path : String) is
      Image : Img.Image := Img.Create ((8, 4));
      Output : Writer.Filter := Writer.Create;
      Input : Reader.Filter := Reader.Create;
   begin
      Fill_2D (Image, 8);
      Output.Set_Input (Image);
      Output.Set_File_Name (Path);
      Output.Update;
      Input.Set_File_Name (Path);
      Input.Update;
      declare
         Back : Img.Image := Input.Get_Output;
      begin
         Check (Region_Matches (Back, 8, 4), "png size");
         Check (Same_Pixels (Image, Back), "png pixels");
      end;
   end Test_Png;

   procedure Test_Missing_File is
   begin
      declare
         Input : Reader.Filter := Reader.Create;
      begin
         Input.Set_File_Name ("/tmp/itklib-no-such-file.png");
         Input.Update;
         Check (False, "missing file should raise");
      end;
   exception
      when Event : Itklib.Itk_Error =>
         Check
           (Ada.Exceptions.Exception_Message (Event)'Length > 0,
            "Itk_Error message");
   end Test_Missing_File;

   procedure Test_Zero_Extent is
   begin
      declare
         Image : Img.Image := Img.Create ((0, 4));
      begin
         Check (Img.Reference_Count (Image) = 0, "unreachable");
      end;
      Check (False, "zero extent should raise");
   exception
      when Itklib.Itk_Error =>
         null;
   end Test_Zero_Extent;

   procedure Test_Unsupported is
      procedure Wrong_Dimension is
         package Bad is new Itklib.Images (Itklib.Pixels.UInt16, 4);
      begin
         null;
      end Wrong_Dimension;

      procedure Wrong_Pixel is
         package Sig is new Itklib.Pixel_Signature
           (Interfaces.IEEE_Float_32, Itklib.Float32);
         package Bad is new Itklib.Images (Sig, 2);
      begin
         null;
      end Wrong_Pixel;
   begin
      begin
         Wrong_Dimension;
         Check (False, "dimension 4 should be rejected");
      exception
         when Itklib.Unsupported_Instantiation =>
            null;
      end;
      begin
         Wrong_Pixel;
         Check (False, "float32 should be rejected");
      exception
         when Itklib.Unsupported_Instantiation =>
            null;
      end;
   end Test_Unsupported;

   function Near
     (Image : in out Img.Image; Value : Interfaces.Unsigned_16;
      Tolerance : Interfaces.Unsigned_16) return Boolean
   is
      Match : Boolean := True;

      procedure Read (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            declare
               Gap : Interfaces.Unsigned_16;
            begin
               if Item >= Value then
                  Gap := Item - Value;
               else
                  Gap := Value - Item;
               end if;
               if Gap > Tolerance then
                  Match := False;
                  return;
               end if;
            end;
         end loop;
      end Read;

      procedure Apply is new Img.With_Buffer (Read);
   begin
      Apply (Image);
      return Match;
   end Near;

   procedure Test_Gaussian is
      Constant_Image : Img.Image := Img.Create ((6, 6));
      Impulse : Img.Image := Img.Create ((8, 8));
      Filter : Smooth.Filter := Smooth.Create;

      procedure Paint_Constant (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 400;
         end loop;
      end Paint_Constant;

      procedure Paint_Impulse (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 0;
         end loop;
         Data (3 + 3 * 8) := 20_000;
      end Paint_Impulse;

      procedure Apply_Constant is new Img.With_Buffer (Paint_Constant);
      procedure Apply_Impulse is new Img.With_Buffer (Paint_Impulse);

      procedure Measure
        (Image : in out Img.Image; Center : out Interfaces.Unsigned_16;
         Neighbor : out Interfaces.Unsigned_16; Total : out Long_Integer)
      is
         procedure Read (Data : in out Img.Pixel_Array) is
         begin
            Total := 0;
            Center := Data (3 + 3 * 8);
            Neighbor := Data (4 + 3 * 8);
            for Item of Data loop
               Total := Total + Long_Integer (Item);
            end loop;
         end Read;

         procedure Apply is new Img.With_Buffer (Read);
      begin
         Apply (Image);
      end Measure;
   begin
      Apply_Constant (Constant_Image);
      Filter.Set_Input (Constant_Image);
      Filter.Set_Variance ((1.0, 1.0));
      Filter.Set_Use_Image_Spacing (False);
      Filter.Update;
      declare
         Result : Img.Image := Filter.Get_Output;
      begin
         --  UInt16 rounding of a normalized kernel can move a constant by 1 or 2.
         Check (Near (Result, 400, 2), "constant image stays near 400");
      end;

      Apply_Impulse (Impulse);
      declare
         Blur : Smooth.Filter := Smooth.Create;
         Center : Interfaces.Unsigned_16;
         Neighbor : Interfaces.Unsigned_16;
         Total : Long_Integer;
      begin
         Blur.Set_Input (Impulse);
         Blur.Set_Variance ((1.0, 1.0));
         Blur.Set_Use_Image_Spacing (False);
         Blur.Update;
         declare
            Blurred : Img.Image := Blur.Get_Output;
         begin
            Measure (Blurred, Center, Neighbor, Total);
         end;
         Check (Center < 20_000, "impulse spreads");
         Check (Neighbor > 0, "neighbor receives energy");
         Check (Total > 19_000 and then Total < 21_000, "kernel roughly preserves sum");
      end;
   end Test_Gaussian;

   procedure Test_Gaussian_3D is
      Volume : Vol.Image := Vol.Create ((4, 4, 4));
      Filter : Smooth3.Filter := Smooth3.Create;

      procedure Paint (Data : in out Vol.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 100;
         end loop;
      end Paint;

      procedure Apply is new Vol.With_Buffer (Paint);

      function Near (Image : in out Vol.Image) return Boolean is
         Match : Boolean := True;

         procedure Read (Data : in out Vol.Pixel_Array) is
         begin
            for Item of Data loop
               if Item < 98 or else Item > 102 then
                  Match := False;
                  return;
               end if;
            end loop;
         end Read;

         procedure Read_Apply is new Vol.With_Buffer (Read);
      begin
         Read_Apply (Image);
         return Match;
      end Near;
   begin
      Apply (Volume);
      Filter.Set_Input (Volume);
      Filter.Set_Variance ((1.0, 1.0, 1.0));
      Filter.Set_Use_Image_Spacing (False);
      Filter.Update;
      declare
         Result : Vol.Image := Filter.Get_Output;
      begin
         Check (Near (Result), "3D constant gaussian");
      end;
   end Test_Gaussian_3D;

   procedure Test_Lazy_Pipeline (Input_Path, Output_Path : String) is
      Input : Reader.Filter := Reader.Create;
      Blur : Smooth.Filter := Smooth.Create;
      Output : Writer.Filter := Writer.Create;
   begin
      Input.Set_File_Name (Input_Path);
      Blur.Set_Input (Input.Get_Output);
      Blur.Set_Variance ((2.0, 2.0));
      Blur.Set_Use_Image_Spacing (False);
      Output.Set_Input (Blur.Get_Output);
      Output.Set_File_Name (Output_Path);
      Output.Update;
      declare
         Back : Reader.Filter := Reader.Create;
      begin
         Back.Set_File_Name (Output_Path);
         Back.Update;
         Check (Region_Matches (Back.Get_Output, 8, 4), "pipeline size");
      end;
   end Test_Lazy_Pipeline;

   procedure Compare_Files (Left_Path, Right_Path : String) is
      Left : Reader.Filter := Reader.Create;
      Right : Reader.Filter := Reader.Create;
   begin
      Left.Set_File_Name (Left_Path);
      Right.Set_File_Name (Right_Path);
      Left.Update;
      Right.Update;
      declare
         A : Img.Image := Left.Get_Output;
         B : Img.Image := Right.Get_Output;
         RA : constant Img.Region := Img.Largest_Possible_Region (A);
         RB : constant Img.Region := Img.Largest_Possible_Region (B);
      begin
         Check (RA.Extent (1) = RB.Extent (1) and then RA.Extent (2) = RB.Extent (2),
            "adaimg size");
         Check (Same_Pixels (A, B), "adaimg pixels");
      end;
   end Compare_Files;

   Sample : constant String := "obj/phase0-uint16.png";
   Blurred : constant String := "obj/phase0-blurred.png";
begin
   Ada.Directories.Create_Path ("obj");
   if Ada.Command_Line.Argument_Count = 3
     and then Ada.Command_Line.Argument (1) = "--compare"
   then
      Compare_Files
        (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3));
   else
      Test_Signature;
      Test_Lifetime_And_Buffer;
      Test_3D;
      Test_Geometry;
      Test_Png (Sample);
      Test_Missing_File;
      Test_Zero_Extent;
      Test_Unsupported;
      Test_Gaussian;
      Test_Gaussian_3D;
      Test_Lazy_Pipeline (Sample, Blurred);
      declare
         Objects : constant Natural := Itklib.Debug_Live_Objects;
         Wrappers : constant Natural := Itklib.Debug_Live_Wrappers;
      begin
         Check (Objects = 0, "no leaked ITK objects");
         Check (Wrappers = 0, "no leaked wrappers");
      end;
   end if;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("itklib phase 0 tests passed");
   else
      Ada.Text_IO.Put_Line ("itklib phase 0 tests failed:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Itklib_Tests;
