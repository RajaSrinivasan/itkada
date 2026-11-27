with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Adaimg_Command;
with Interfaces;
with Itklib.Core.Regions;
with Itklib.Filters.Image_Gradient.Gradient_Magnitude;
with Itklib.Filters.Image_Grid.Extract;
with Itklib.Filters.Image_Grid.Flip;
with Itklib.Filters.Image_Grid.Resample;
with Itklib.Filters.Image_Grid.Shrink;
with Itklib.Filters.Image_Intensity.Rescale_Intensity;
with Itklib.Filters.Image_Statistics.Statistics;
with Itklib.Filters.Smoothing.Discrete_Gaussian;
with Itklib.Filters.Smoothing.Median;
with Itklib.Filters.Thresholding.Binary_Threshold;
with Itklib.IO.Image_File_Reader;
with Itklib.IO.Image_File_Writer;
with Itklib.Images;
with Itklib.Images.Region_Iterators;
with Itklib.Pixels.UInt16;

procedure Phase1_Tests is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_64;

   package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
   package Vol is new Itklib.Images (Itklib.Pixels.UInt16, 3);
   package Walk2 is new Img.Region_Iterators;
   package Space2 is new Itklib.Core.Regions (2);
   package Space3 is new Itklib.Core.Regions (3);
   package Reader is new Itklib.IO.Image_File_Reader (Img);
   package Writer is new Itklib.IO.Image_File_Writer (Img);
   package Stats is new Itklib.Filters.Image_Statistics.Statistics (Img);
   package Stats3 is new Itklib.Filters.Image_Statistics.Statistics (Vol);
   package Median is new Itklib.Filters.Smoothing.Median (Img, Img);
   package Median3 is new Itklib.Filters.Smoothing.Median (Vol, Vol);
   package Thresh is new Itklib.Filters.Thresholding.Binary_Threshold (Img, Img);
   package Thresh3 is new Itklib.Filters.Thresholding.Binary_Threshold (Vol, Vol);
   package Rescale is new Itklib.Filters.Image_Intensity.Rescale_Intensity (Img, Img);
   package Rescale3 is new Itklib.Filters.Image_Intensity.Rescale_Intensity (Vol, Vol);
   package Shrink is new Itklib.Filters.Image_Grid.Shrink (Img, Img);
   package Shrink3 is new Itklib.Filters.Image_Grid.Shrink (Vol, Vol);
   package Resample is new Itklib.Filters.Image_Grid.Resample (Img, Img);
   package Resample3 is new Itklib.Filters.Image_Grid.Resample (Vol, Vol);
   package Flip is new Itklib.Filters.Image_Grid.Flip (Img);
   package Flip3 is new Itklib.Filters.Image_Grid.Flip (Vol);
   package Crop is new Itklib.Filters.Image_Grid.Extract (Img, Img);
   package Crop3 is new Itklib.Filters.Image_Grid.Extract (Vol, Vol);
   package Edge is new Itklib.Filters.Image_Gradient.Gradient_Magnitude (Img, Img);
   package Edge3 is new Itklib.Filters.Image_Gradient.Gradient_Magnitude (Vol, Vol);
   package Smooth is new Itklib.Filters.Smoothing.Discrete_Gaussian (Img, Img);

   use type Img.Index;
   use type Img.Size;
   use type Vol.Size;
   use type Adaimg_Command.Mode_Kind;
   use type Adaimg_Command.Op_Kind;

   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line ("FAIL: " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   function Near (Left, Right : Long_Float) return Boolean is
      (abs (Left - Right) < 1.0e-9);

   procedure Test_Regions is
      R2 : constant Space2.Region :=
        (Start => [0, 1], Extent => [3, 2]);
      R3 : constant Space3.Region :=
        (Start => [0, 0, 0], Extent => [2, 2, 2]);
      Seen : Natural := 0;

      procedure Visit2 (Idx : Space2.Index; Off : Interfaces.Unsigned_64) is
      begin
         Check (Space2.Offset (R2, Idx) = Off, "2D offset matches cursor");
         Check (Space2.Inside (R2, Idx), "2D cursor index is inside");
         Seen := Seen + 1;
      end Visit2;

      procedure Walk_R2 is new Space2.Walk (Visit2);

      procedure Visit3 (Idx : Space3.Index; Off : Interfaces.Unsigned_64) is
      begin
         Check
           (Off = Interfaces.Unsigned_64 (Idx (1)) +
              Interfaces.Unsigned_64 (Idx (2)) * 2 +
              Interfaces.Unsigned_64 (Idx (3)) * 4,
            "3D offset is x-fastest");
         Seen := Seen + 1;
      end Visit3;

      procedure Walk_R3 is new Space3.Walk (Visit3);
   begin
      Check (Space2.Fits (R2), "2D region fits");
      Check (Space2.Volume (R2.Extent) = 6, "2D volume");
      Check (not Space2.Inside (R2, [3, 1]), "2D index past x is outside");
      Check (not Space2.Inside (R2, [0, 0]), "2D index before y is outside");
      Check (Space2.Offset (R2, [2, 2]) = 5, "2D offset of last pixel");
      Check
        (not Space2.Product_Bounded ([Interfaces.Unsigned_64'Last, 2]),
         "product overflow is rejected");
      Walk_R2 (R2);
      Check (Seen = 6, "2D walk visits every pixel");
      Seen := 0;
      Walk_R3 (R3);
      Check (Seen = 8, "3D walk visits every pixel");

      declare
         Region : constant Img.Region := (Start => [0, 0], Extent => [2, 2]);
         Order : array (0 .. 3) of Img.Index;
         Count : Natural := 0;

         procedure Visit (Idx : Img.Index; Off : Interfaces.Unsigned_64) is
         begin
            Order (Natural (Off)) := Idx;
            Count := Count + 1;
         end Visit;

         procedure Go is new Walk2.Walk (Visit);
         Cursor : Walk2.Cursor := Walk2.First (Region);
      begin
         Go (Region);
         Check (Count = 4, "image iterator count");
         Check (Order (0) = [0, 0] and then Order (1) = [1, 0], "x varies fastest");
         Check (Order (2) = [0, 1] and then Order (3) = [1, 1], "y is the slow axis");
         Check (Walk2.Has_Element (Cursor), "first cursor is live");
         Cursor := Walk2.Next (Cursor);
         Check (Walk2.Index_Of (Cursor) = [1, 0], "next cursor steps in x");
      end;
   end Test_Regions;

   procedure Test_Geometry is
      Image : Img.Image := Img.Create ([4, 4]);
      Volume : Vol.Image := Vol.Create ([2, 2, 2]);
      Idx : constant Img.Index := [2, 3];
      Point : Img.Vector;
      Back : Img.Index;
   begin
      Image.Set_Spacing ([0.5, 2.0]);
      Image.Set_Origin ([1.0, -4.0]);
      Image.Set_Direction ([[1.0, 0.0], [0.0, 1.0]]);
      Point := Image.Transform_Index_To_Physical_Point (Idx);
      Check (Near (Point (1), 2.0) and then Near (Point (2), 2.0), "identity physical point");
      Back := Image.Transform_Physical_Point_To_Index (Point);
      Check (Back = Idx, "identity point rounds back to the index");
      declare
         Pure : constant Space2.Vector :=
           Space2.To_Physical
             ([2, 3], [0.5, 2.0], [1.0, -4.0], [[1.0, 0.0], [0.0, 1.0]]);
      begin
         Check (Near (Pure (1), Point (1)) and then Near (Pure (2), Point (2)),
            "Ada geometry matches ITK");
      end;

      Image.Set_Direction ([[0.0, -1.0], [1.0, 0.0]]);
      Point := Image.Transform_Index_To_Physical_Point (Idx);
      Check (Near (Point (1), -5.0) and then Near (Point (2), -3.0), "rotated physical point");
      Back := Image.Transform_Physical_Point_To_Index (Point);
      Check (Back = Idx, "rotated point rounds back to the index");

      Volume.Set_Spacing ([1.0, 2.0, 4.0]);
      Volume.Set_Origin ([0.0, 0.0, 0.0]);
      declare
         Where : constant Vol.Vector :=
           Volume.Transform_Index_To_Physical_Point ([1, 1, 1]);
      begin
         Check
           (Near (Where (1), 1.0) and then Near (Where (2), 2.0)
            and then Near (Where (3), 4.0),
            "3D physical point");
      end;
   end Test_Geometry;

   function Pixel_At
     (Image : in out Img.Image; X, Y : Natural) return Interfaces.Unsigned_16
   is
      Found : Interfaces.Unsigned_16 := 0;
      Width : constant Interfaces.Unsigned_64 :=
        Img.Largest_Possible_Region (Image).Extent (1);

      procedure Read (Data : in out Img.Pixel_Array) is
         Off : constant Interfaces.Unsigned_64 :=
           Interfaces.Unsigned_64 (X) + Interfaces.Unsigned_64 (Y) * Width;
      begin
         Found := Data (Off);
      end Read;

      procedure Apply is new Img.With_Buffer (Read);
   begin
      Apply (Image);
      return Found;
   end Pixel_At;

   procedure Paint
     (Image : in out Img.Image;
      Values : Interfaces.Unsigned_16)
   is
      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := Values;
         end loop;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Image);
   end Paint;

   procedure Test_Buffer_Lock is
      Source : Img.Image := Img.Create ([4, 4]);
      Filter : Thresh.Filter := Thresh.Create;
      Raised : Boolean := False;

      procedure Touch (Data : in out Img.Pixel_Array) is
         pragma Unreferenced (Data);
      begin
         Filter.Update;
      exception
         when Itklib.Itk_Error =>
            Raised := True;
      end Touch;

      procedure Apply is new Img.With_Buffer (Touch);
   begin
      Paint (Source, 10);
      Filter.Set_Input (Source);
      Filter.Set_Lower_Threshold (0.0);
      Filter.Set_Upper_Threshold (20.0);
      Filter.Update;
      declare
         Result : Img.Image := Filter.Get_Output;
      begin
         Apply (Result);
      end;
      Check (Raised, "Update during With_Buffer is rejected");
   end Test_Buffer_Lock;

   procedure Test_Statistics is
      Image : Img.Image := Img.Create ([2, 2]);
      Filter : Stats.Filter := Stats.Create;

      procedure Write (Data : in out Img.Pixel_Array) is
      begin
         Data (0) := 1;
         Data (1) := 2;
         Data (2) := 3;
         Data (3) := 6;
      end Write;

      procedure Apply is new Img.With_Buffer (Write);
   begin
      Apply (Image);
      Filter.Set_Input (Image);
      Filter.Update;
      Check (Filter.Minimum = 1.0, "minimum");
      Check (Filter.Maximum = 6.0, "maximum");
      Check (Near (Filter.Mean, 3.0), "mean");
   end Test_Statistics;

   procedure Test_Filters is
      Ramp : Img.Image := Img.Create ([8, 1]);
      Block : Img.Image := Img.Create ([5, 5]);
      Wide : Img.Image := Img.Create ([4, 6]);

      procedure Write_Ramp (Data : in out Img.Pixel_Array) is
      begin
         for K in Data'Range loop
            Data (K) := Interfaces.Unsigned_16 (K);
         end loop;
      end Write_Ramp;

      procedure Write_Block (Data : in out Img.Pixel_Array) is
      begin
         for Item of Data loop
            Item := 0;
         end loop;
         for Y in 1 .. 3 loop
            for X in 1 .. 3 loop
               Data (Interfaces.Unsigned_64 (X + Y * 5)) := 1_000;
            end loop;
         end loop;
      end Write_Block;

      procedure Write_Wide (Data : in out Img.Pixel_Array) is
      begin
         for K in Data'Range loop
            Data (K) := Interfaces.Unsigned_16 (K);
         end loop;
      end Write_Wide;

      procedure Apply_Ramp is new Img.With_Buffer (Write_Ramp);
      procedure Apply_Block is new Img.With_Buffer (Write_Block);
      procedure Apply_Wide is new Img.With_Buffer (Write_Wide);
   begin
      Apply_Ramp (Ramp);
      declare
         Filter : Thresh.Filter := Thresh.Create;
      begin
         Filter.Set_Input (Ramp);
         Filter.Set_Lower_Threshold (2.0);
         Filter.Set_Upper_Threshold (5.0);
         Filter.Set_Inside_Value (9.0);
         Filter.Set_Outside_Value (1.0);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Pixel_At (Result, 0, 0) = 1, "threshold outside low");
            Check (Pixel_At (Result, 2, 0) = 9, "threshold inside");
            Check (Pixel_At (Result, 5, 0) = 9, "threshold upper bound");
            Check (Pixel_At (Result, 6, 0) = 1, "threshold outside high");
         end;
      end;

      declare
         Filter : Rescale.Filter := Rescale.Create;
         Ends : Img.Image := Img.Create ([2, 1]);

         procedure Write (Data : in out Img.Pixel_Array) is
         begin
            Data (0) := 0;
            Data (1) := 1_000;
         end Write;

         procedure Apply is new Img.With_Buffer (Write);
      begin
         Apply (Ends);
         Filter.Set_Input (Ends);
         Filter.Set_Output_Minimum (0.0);
         Filter.Set_Output_Maximum (100.0);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Pixel_At (Result, 0, 0) = 0, "rescale minimum");
            Check (Pixel_At (Result, 1, 0) = 100, "rescale maximum");
         end;
      end;

      Apply_Block (Block);
      declare
         Filter : Median.Filter := Median.Create;
      begin
         Filter.Set_Input (Block);
         Filter.Set_Radius ([1, 1]);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Pixel_At (Result, 2, 2) = 1_000, "median keeps the block center");
            Check (Pixel_At (Result, 0, 0) = 0, "median keeps the corner");
         end;
      end;

      Apply_Wide (Wide);
      declare
         Filter : Shrink.Filter := Shrink.Create;
      begin
         Filter.Set_Input (Wide);
         Filter.Set_Shrink_Factors ([2, 2]);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
            Region : constant Img.Region := Img.Largest_Possible_Region (Result);
            Space : constant Img.Vector := Result.Spacing;
         begin
            Check (Region.Extent = [2, 3], "shrink size");
            --  Default spacing is 1; ITK multiplies it by the shrink factor
            --  and shifts the origin so the physical centers match. The
            --  sample at output (0,0) is therefore input (1,1), not (0,0).
            Check (Near (Space (1), 2.0) and then Near (Space (2), 2.0), "shrink spacing");
            Check (Pixel_At (Result, 0, 0) = Pixel_At (Wide, 1, 1), "shrink samples the centered pixel");
         end;
      end;

      declare
         Filter : Resample.Filter := Resample.Create;
         Source : Img.Image := Img.Create ([4, 4]);
      begin
         Paint (Source, 40);
         Filter.Set_Input (Source);
         Filter.Set_Output_Spacing ([1.0 / 1.5, 1.0 / 1.5]);
         Filter.Set_Output_Origin (Source.Origin);
         Filter.Set_Output_Direction (Source.Image_Direction);
         Filter.Set_Output_Size ([6, 6]);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
            Region : constant Img.Region := Img.Largest_Possible_Region (Result);
         begin
            Check (Region.Extent = [6, 6], "resample size");
            Check (Pixel_At (Result, 0, 0) = 40, "resample keeps the interior");
         end;
      end;

      declare
         Filter : Flip.Filter := Flip.Create;
         Source : Img.Image := Img.Create ([3, 2]);

         procedure Write (Data : in out Img.Pixel_Array) is
         begin
            Data (0) := 1;
            Data (1) := 2;
            Data (2) := 3;
            Data (3) := 4;
            Data (4) := 5;
            Data (5) := 6;
         end Write;

         procedure Apply is new Img.With_Buffer (Write);
      begin
         Apply (Source);
         Filter.Set_Input (Source);
         Filter.Set_Flip_Axes ([True, False]);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Pixel_At (Result, 0, 0) = 3, "flip x first");
            Check (Pixel_At (Result, 2, 0) = 1, "flip x last");
            Check (Pixel_At (Result, 0, 1) = 6, "flip x second row");
         end;
         Filter.Set_Flip_Axes ([False, True]);
         Filter.Modified;
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Pixel_At (Result, 0, 0) = 4, "flip y first");
            Check (Pixel_At (Result, 2, 1) = 3, "flip y last");
         end;
      end;

      declare
         Filter : Crop.Filter := Crop.Create;
      begin
         Filter.Set_Input (Ramp);
         Filter.Set_Extraction_Region ((Start => [1, 0], Extent => [3, 1]));
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Img.Largest_Possible_Region (Result).Extent = [3, 1], "crop size");
            Check (Pixel_At (Result, 0, 0) = 1, "crop first pixel");
            Check (Pixel_At (Result, 2, 0) = 3, "crop last pixel");
         end;
         begin
            Filter.Set_Extraction_Region ((Start => [0, 0], Extent => [100, 1]));
            Filter.Update;
            Check (False, "out of bounds crop should fail");
         exception
            when Itklib.Itk_Error =>
               null;
         end;
      end;

      declare
         Filter : Edge.Filter := Edge.Create;
         Source : Img.Image := Img.Create ([6, 4]);
         Hot : Boolean := False;

         procedure Write (Data : in out Img.Pixel_Array) is
         begin
            for K in Data'Range loop
               if K mod 6 < 3 then
                  Data (K) := 0;
               else
                  Data (K) := 1_000;
               end if;
            end loop;
         end Write;

         procedure Read (Data : in out Img.Pixel_Array) is
         begin
            for Item of Data loop
               if Item > 0 then
                  Hot := True;
               end if;
            end loop;
         end Read;

         procedure Apply_Write is new Img.With_Buffer (Write);
         procedure Apply_Read is new Img.With_Buffer (Read);
      begin
         Apply_Write (Source);
         Filter.Set_Input (Source);
         Filter.Set_Use_Image_Spacing (False);
         Filter.Set_Number_Of_Work_Units (1);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check
              (Img.Largest_Possible_Region (Result).Extent = [6, 4],
               "gradient size");
            Apply_Read (Result);
            Check (Hot, "gradient sees the step");
         end;
      end;

      declare
         Filter : Smooth.Filter := Smooth.Create;
         Source : Img.Image := Img.Create ([4, 4]);
      begin
         Paint (Source, 80);
         Filter.Set_Input (Source);
         Filter.Set_Variance ([1.0, 1.0]);
         Filter.Set_Maximum_Error ([0.1, 0.1]);
         Filter.Set_Use_Image_Spacing (False);
         Filter.Update;
         declare
            Result : Img.Image := Filter.Get_Output;
         begin
            Check (Pixel_At (Result, 1, 1) in 78 .. 82, "maximum error gaussian");
         end;
      end;
   end Test_Filters;

   procedure Test_3D is
      Volume : Vol.Image := Vol.Create ([4, 4, 4]);

      procedure Write (Data : in out Vol.Pixel_Array) is
      begin
         for K in Data'Range loop
            Data (K) := Interfaces.Unsigned_16 (10 + (K mod 7));
         end loop;
      end Write;

      procedure Apply is new Vol.With_Buffer (Write);
   begin
      Apply (Volume);
      declare
         Filter : Stats3.Filter := Stats3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Update;
         Check (Filter.Minimum = 10.0, "3D minimum");
         Check (Filter.Maximum = 16.0, "3D maximum");
      end;
      declare
         Filter : Median3.Filter := Median3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Radius ([1, 1, 1]);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [4, 4, 4],
            "3D median size");
      end;
      declare
         Filter : Thresh3.Filter := Thresh3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Lower_Threshold (12.0);
         Filter.Set_Upper_Threshold (14.0);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [4, 4, 4],
            "3D threshold size");
      end;
      declare
         Filter : Rescale3.Filter := Rescale3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Output_Minimum (0.0);
         Filter.Set_Output_Maximum (50.0);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [4, 4, 4],
            "3D rescale size");
      end;
      declare
         Filter : Shrink3.Filter := Shrink3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Shrink_Factors ([2, 2, 2]);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [2, 2, 2],
            "3D shrink size");
      end;
      declare
         Filter : Resample3.Filter := Resample3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Output_Size ([3, 3, 3]);
         Filter.Set_Output_Spacing ([1.0, 1.0, 1.0]);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [3, 3, 3],
            "3D resample size");
      end;
      declare
         Filter : Flip3.Filter := Flip3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Flip_Axes ([False, False, True]);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [4, 4, 4],
            "3D flip size");
      end;
      declare
         Filter : Crop3.Filter := Crop3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Set_Extraction_Region ((Start => [1, 1, 1], Extent => [2, 2, 2]));
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [2, 2, 2],
            "3D crop size");
      end;
      declare
         Filter : Edge3.Filter := Edge3.Create;
      begin
         Filter.Set_Input (Volume);
         Filter.Update;
         Check
           (Vol.Largest_Possible_Region (Filter.Get_Output).Extent = [4, 4, 4],
            "3D gradient size");
      end;
   end Test_3D;

   procedure Test_Dropped_Pipeline (Input_Path, Output_Path : String) is
      Output : Writer.Filter := Writer.Create;
      Current : Img.Image;
   begin
      declare
         Input : Reader.Filter := Reader.Create;
         Blur : Smooth.Filter := Smooth.Create;
      begin
         Input.Set_File_Name (Input_Path);
         Blur.Set_Input (Input.Get_Output);
         Blur.Set_Variance ([1.0, 1.0]);
         Blur.Set_Use_Image_Spacing (False);
         Current := Blur.Get_Output;
      end;
      Output.Set_Input (Current);
      Output.Set_File_Name (Output_Path);
      Output.Update;
      declare
         Back : Reader.Filter := Reader.Create;
      begin
         Back.Set_File_Name (Output_Path);
         Back.Update;
         Check
           (Img.Largest_Possible_Region (Back.Get_Output).Extent = [8, 4],
            "dropped filters still run");
      end;
   end Test_Dropped_Pipeline;

   procedure Test_Disconnect (Path : String) is
      Input : Reader.Filter := Reader.Create;
   begin
      Input.Set_File_Name (Path);
      Input.Update_Largest_Possible_Region;
      declare
         Image : Img.Image := Input.Get_Output;
      begin
         Image.Disconnect_Pipeline;
         declare
            Kept : constant Interfaces.Unsigned_16 := Pixel_At (Image, 0, 0);
         begin
            Check (Kept = Pixel_At (Image, 0, 0), "disconnected buffer stays readable");
         end;
      end;
   end Test_Disconnect;

   procedure Test_Spacing_Round_Trip (Path : String) is
      Image : Img.Image := Img.Create ([4, 4]);
      Output : Writer.Filter := Writer.Create;
   begin
      Paint (Image, 7);
      Image.Set_Spacing ([0.5, 2.0]);
      Output.Set_Input (Image);
      Output.Set_File_Name (Path);
      Output.Update;
      declare
         Input : Reader.Filter := Reader.Create;
      begin
         Input.Set_File_Name (Path);
         Input.Update;
         declare
            Back : constant Img.Image := Input.Get_Output;
            Space : constant Img.Vector := Back.Spacing;
         begin
            --  PNG pHYs stores pixels per metre as integers, so spacing
            --  comes back quantized. 0.5 and 2.0 are exact in that encoding.
            Check (Near (Space (1), 0.5) and then Near (Space (2), 2.0),
               "PNG preserves this spacing");
         end;
      end;
   end Test_Spacing_Round_Trip;

   function Bounded (Text : String) return Adaimg_Command.Texts.Bounded_String is
     (Adaimg_Command.Texts.To_Bounded_String (Text));

   procedure Test_Parser is
      Copy : constant Adaimg_Command.Command :=
        Adaimg_Command.Parse ([Bounded ("in.png"), Bounded ("out.png")]);
      Identify : constant Adaimg_Command.Command :=
        Adaimg_Command.Parse ([Bounded ("identify"), Bounded ("chest.png")]);
      Chain : constant Adaimg_Command.Command :=
        Adaimg_Command.Parse
          ([Bounded ("in.png"), Bounded ("-blur"), Bounded ("2"),
            Bounded ("-resize"), Bounded ("50%"), Bounded ("-resize"),
            Bounded ("150%"), Bounded ("-flip"), Bounded ("y"),
            Bounded ("-crop"), Bounded ("4x3+1+2"), Bounded ("out.png")]);
      Bad : constant Adaimg_Command.Command :=
        Adaimg_Command.Parse ([Bounded ("in.png"), Bounded ("-nope"), Bounded ("out.png")]);
   begin
      Check (Copy.Mode = Adaimg_Command.Pipeline and then Copy.Count = 0, "copy parse");
      Check (Identify.Mode = Adaimg_Command.Identify, "identify parse");
      Check (Chain.Count = 5, "chain count");
      Check (Chain.Ops (1).Kind = Adaimg_Command.Blur, "blur op");
      Check (Near (Chain.Ops (1).Sigma, 2.0), "blur sigma");
      Check
        (Chain.Ops (2).Kind = Adaimg_Command.Resize_Shrink
         and then Chain.Ops (2).Shrink_Factor = 2,
         "50% shrink");
      Check
        (Chain.Ops (3).Kind = Adaimg_Command.Resize_Resample
         and then Near (Chain.Ops (3).Scale, 1.5),
         "150% resample");
      Check (Chain.Ops (4).Flip_Axis = 2, "flip y");
      Check
        (Chain.Ops (5).Crop_W = 4 and then Chain.Ops (5).Crop_H = 3
         and then Chain.Ops (5).Crop_X = 1 and then Chain.Ops (5).Crop_Y = 2,
         "crop geometry");
      Check (Bad.Mode = Adaimg_Command.Usage_Error, "unknown option");
   end Test_Parser;

   Sample : constant String := "obj/phase0-uint16.png";
   Dropped : constant String := "obj/phase1-dropped.png";
   Spacing_Path : constant String := "obj/phase1-spacing.png";
begin
   Ada.Directories.Create_Path ("obj");
   Test_Regions;
   Test_Geometry;
   Test_Buffer_Lock;
   Test_Statistics;
   Test_Filters;
   Test_3D;
   Test_Dropped_Pipeline (Sample, Dropped);
   Test_Disconnect (Sample);
   Test_Spacing_Round_Trip (Spacing_Path);
   Test_Parser;
   declare
      Objects : constant Natural := Itklib.Debug_Live_Objects;
      Wrappers : constant Natural := Itklib.Debug_Live_Wrappers;
   begin
      Check (Objects = 0, "no leaked ITK objects");
      Check (Wrappers = 0, "no leaked wrappers");
   end;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("itklib phase 1 tests passed");
   else
      Ada.Text_IO.Put_Line ("itklib phase 1 tests failed:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Phase1_Tests;
