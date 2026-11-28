with Ada.Command_Line;
with Ada.Text_IO;
with Adaimg_Command;
with Interfaces;
with Itklib.Filters.Image_Intensity.Cast;
with Itklib.Filters.Image_Intensity.Intensity_Windowing;
with Itklib.Filters.Image_Intensity.Invert_Intensity;
with Itklib.Filters.Image_Intensity.Sigmoid;
with Itklib.Filters.Morphology.Binary_Erode;
with Itklib.Filters.Morphology.Binary_Fillhole;
with Itklib.Filters.Morphology.Grayscale_Dilate;
with Itklib.Filters.Morphology.Grayscale_Erode;
with Itklib.Filters.Region_Growing.Confidence_Connected;
with Itklib.Filters.Region_Growing.Connected_Threshold;
with Itklib.Filters.Smoothing.Mean;
with Itklib.Filters.Thresholding.Otsu_Threshold;
with Itklib.Images;
with Itklib.Pixels.UInt16;

procedure Phase3_Tests is
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_64;
   use type Adaimg_Command.Mode_Kind;
   use type Adaimg_Command.Op_Kind;

   package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
   package Erode is new Itklib.Filters.Morphology.Grayscale_Erode (Img, Img);
   package Dilate is new Itklib.Filters.Morphology.Grayscale_Dilate (Img, Img);
   package Binary is new Itklib.Filters.Morphology.Binary_Erode (Img, Img);
   package Holes is new Itklib.Filters.Morphology.Binary_Fillhole (Img, Img);
   package Otsu is new Itklib.Filters.Thresholding.Otsu_Threshold (Img, Img);
   package Grow is new Itklib.Filters.Region_Growing.Connected_Threshold (Img, Img);
   package Confidence is new Itklib.Filters.Region_Growing.Confidence_Connected (Img, Img);
   package Cast is new Itklib.Filters.Image_Intensity.Cast (Img, Img);
   package Window is new Itklib.Filters.Image_Intensity.Intensity_Windowing (Img, Img);
   package Sigmoid is new Itklib.Filters.Image_Intensity.Sigmoid (Img, Img);
   package Invert is new Itklib.Filters.Image_Intensity.Invert_Intensity (Img, Img);
   package Mean is new Itklib.Filters.Smoothing.Mean (Img, Img);

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line ("FAIL: " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   function Pixel_At
     (Image : in out Img.Image; X, Y : Natural; Width : Positive)
      return Interfaces.Unsigned_16
   is
      Found : Interfaces.Unsigned_16 := 0;

      procedure Read (Data : in out Img.Pixel_Array) is
      begin
         Found :=
           Data (Interfaces.Unsigned_64 (X) + Interfaces.Unsigned_64 (Y) * Interfaces.Unsigned_64 (Width));
      end Read;

      procedure Apply is new Img.With_Buffer (Read);
   begin
      Apply (Image);
      return Found;
   end Pixel_At;

   procedure Paint_Spot (Image : in out Img.Image) is
      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 0;
         end loop;
         Data (3 + 3 * 8) := 4000;
         Data (4 + 3 * 8) := 4000;
         Data (3 + 4 * 8) := 4000;
         Data (4 + 4 * 8) := 4000;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Image);
   end Paint_Spot;

   procedure Test_Morphology is
      Source : Img.Image := Img.Create ([8, 8]);
      E : Erode.Filter := Erode.Create;
      D : Dilate.Filter := Dilate.Create;
   begin
      Paint_Spot (Source);
      E.Set_Input (Source);
      E.Set_Radius ([1, 1]);
      E.Update;
      declare
         Result : Img.Image := E.Get_Output;
      begin
         Check (Pixel_At (Result, 3, 3, 8) < 4000, "erode lowers the spot corner");
      end;
      D.Set_Input (Source);
      D.Set_Radius ([1, 1]);
      D.Update;
      declare
         Result : Img.Image := D.Get_Output;
      begin
         Check (Pixel_At (Result, 2, 2, 8) > 0, "dilate spreads the spot");
      end;
   end Test_Morphology;

   procedure Test_Otsu is
      Source : Img.Image := Img.Create ([4, 4]);
      F : Otsu.Filter := Otsu.Create;

      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for Index in Data'Range loop
            if Index < 8 then
               Data (Index) := 100;
            else
               Data (Index) := 5000;
            end if;
         end loop;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Source);
      F.Set_Input (Source);
      F.Set_Inside_Value (65_535.0);
      F.Set_Outside_Value (0.0);
      F.Update;
      declare
         Result : Img.Image := F.Get_Output;
         Level : constant Long_Float := F.Threshold;
      begin
         Check (Level > 100.0 and then Level < 5000.0, "otsu level sits between the modes");
         Check
           (Pixel_At (Result, 0, 0, 4) = 0 or else Pixel_At (Result, 0, 0, 4) = 65_535,
            "otsu writes a binary value");
      end;
   end Test_Otsu;

   procedure Test_Grow is
      Source : Img.Image := Img.Create ([4, 4]);
      F : Grow.Filter := Grow.Create;

      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 10;
         end loop;
         Data (0) := 1000;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Source);
      F.Set_Input (Source);
      F.Set_Lower (0.0);
      F.Set_Upper (50.0);
      F.Set_Replace_Value (7.0);
      F.Set_Seed ([0, 1]);
      F.Update;
      declare
         Result : Img.Image := F.Get_Output;
      begin
         Check (Pixel_At (Result, 0, 1, 4) = 7, "grow replaces the seed");
         Check (Pixel_At (Result, 0, 0, 4) /= 7, "grow leaves the bright pixel outside");
      end;
   end Test_Grow;

   procedure Test_Confidence is
      Source : Img.Image := Img.Create ([4, 4]);
      F : Confidence.Filter := Confidence.Create;

      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 20;
         end loop;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Source);
      F.Set_Input (Source);
      F.Set_Multiplier (2.0);
      F.Set_Number_Of_Iterations (1);
      F.Set_Initial_Neighborhood_Radius (1);
      F.Set_Replace_Value (9.0);
      F.Set_Seed ([1, 1]);
      F.Update;
      declare
         Result : Img.Image := F.Get_Output;
      begin
         Check (Pixel_At (Result, 1, 1, 4) = 9, "confidence replaces the seed");
      end;
   end Test_Confidence;

   procedure Test_Cast_And_Intensity is
      Source : Img.Image := Img.Create ([2, 2]);
      As_Cast : Cast.Filter := Cast.Create;
      As_Window : Window.Filter := Window.Create;
      As_Sigmoid : Sigmoid.Filter := Sigmoid.Create;
      As_Invert : Invert.Filter := Invert.Create;
      As_Mean : Mean.Filter := Mean.Create;

      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         Data (0) := 0;
         Data (1) := 1000;
         Data (2) := 2000;
         Data (3) := 3000;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Source);
      As_Cast.Set_Input (Source);
      As_Cast.Update;
      declare
         Result : Img.Image := As_Cast.Get_Output;
      begin
         Check (Pixel_At (Result, 1, 0, 2) = 1000, "cast to the same pixel is identity");
      end;
      As_Window.Set_Input (Source);
      As_Window.Set_Window_Minimum (1000.0);
      As_Window.Set_Window_Maximum (2000.0);
      As_Window.Set_Output_Minimum (0.0);
      As_Window.Set_Output_Maximum (100.0);
      As_Window.Update;
      declare
         Result : Img.Image := As_Window.Get_Output;
      begin
         Check (Pixel_At (Result, 0, 0, 2) = 0, "window clamps below the window");
         Check (Pixel_At (Result, 1, 1, 2) = 100, "window clamps above the window");
      end;
      As_Sigmoid.Set_Input (Source);
      As_Sigmoid.Set_Alpha (500.0);
      As_Sigmoid.Set_Beta (1500.0);
      As_Sigmoid.Set_Output_Minimum (0.0);
      As_Sigmoid.Set_Output_Maximum (1000.0);
      As_Sigmoid.Update;
      declare
         Result : Img.Image := As_Sigmoid.Get_Output;
      begin
         Check (Img.Reference_Count (Result) > 0, "sigmoid produces an image");
      end;
      As_Invert.Set_Input (Source);
      As_Invert.Set_Maximum (3000.0);
      As_Invert.Update;
      declare
         Result : Img.Image := As_Invert.Get_Output;
      begin
         Check (Pixel_At (Result, 0, 0, 2) = 3000, "invert maps zero to the maximum");
      end;
      As_Mean.Set_Input (Source);
      As_Mean.Set_Radius ([1, 1]);
      As_Mean.Update;
      declare
         Result : Img.Image := As_Mean.Get_Output;
      begin
         Check (Img.Reference_Count (Result) > 0, "mean produces an image");
      end;
   end Test_Cast_And_Intensity;

   procedure Test_Binary is
      Source : Img.Image := Img.Create ([5, 5]);
      F : Binary.Filter := Binary.Create;
      Hole : Holes.Filter := Holes.Create;

      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 1;
         end loop;
         Data (2 + 2 * 5) := 0;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Source);
      F.Set_Input (Source);
      F.Set_Radius ([1, 1]);
      F.Set_Foreground_Value (1.0);
      F.Set_Background_Value (0.0);
      F.Update;
      declare
         Result : Img.Image := F.Get_Output;
      begin
         Check (Img.Reference_Count (Result) > 0, "binary erode produces an image");
      end;
      Hole.Set_Input (Source);
      Hole.Set_Foreground_Value (1.0);
      Hole.Set_Fully_Connected (False);
      Hole.Update;
      declare
         Result : Img.Image := Hole.Get_Output;
      begin
         Check (Pixel_At (Result, 2, 2, 5) = 1, "fillhole fills the interior zero");
      end;
   end Test_Binary;

   procedure Test_Parser is
      package Texts renames Adaimg_Command.Texts;

      function T (Value : String) return Texts.Bounded_String is
        (Texts.To_Bounded_String (Value));

      Args : constant Adaimg_Command.Arg_Array :=
        [T ("in.png"), T ("-erode"), T ("1"), T ("-otsu"), T ("-grow"),
         T ("2,3,10:40"), T ("out.png")];
      Command : constant Adaimg_Command.Command := Adaimg_Command.Parse (Args);
   begin
      Check (Command.Mode = Adaimg_Command.Pipeline, "medical options parse");
      Check (Command.Count = 3, "three medical operations");
      Check (Command.Ops (1).Kind = Adaimg_Command.Erode, "erode");
      Check (Command.Ops (1).Radius = 1, "erode radius");
      Check (Command.Ops (2).Kind = Adaimg_Command.Otsu, "otsu");
      Check (Command.Ops (3).Kind = Adaimg_Command.Grow, "grow");
      Check (Command.Ops (3).Seed_X = 2 and then Command.Ops (3).Seed_Y = 3, "grow seed");
      Check (Command.Ops (3).Low = 10.0 and then Command.Ops (3).High = 40.0, "grow range");
   end Test_Parser;

begin
   Test_Morphology;
   Test_Otsu;
   Test_Grow;
   Test_Confidence;
   Test_Cast_And_Intensity;
   Test_Binary;
   Test_Parser;
   if Failures /= 0 then
      Ada.Text_IO.Put_Line ("phase 3 failures:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("itklib phase 3 tests passed");
   end if;
end Phase3_Tests;
