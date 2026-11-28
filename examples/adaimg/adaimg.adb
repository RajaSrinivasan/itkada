with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Long_Float_Text_IO;
with Ada.Text_IO;
with Adaimg_Command;
with Interfaces;
with Itklib.Filters.Image_Gradient.Gradient_Magnitude;
with Itklib.Filters.Image_Grid.Extract;
with Itklib.Filters.Morphology.Grayscale_Dilate;
with Itklib.Filters.Morphology.Grayscale_Erode;
with Itklib.Filters.Region_Growing.Connected_Threshold;
with Itklib.Filters.Thresholding.Otsu_Threshold;
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
with Itklib.Pixels.UInt16;

procedure Adaimg is
   --  Phase 1 CLI. Options only connect a lazy pipeline. The writer's
   --  Update runs it. Filter variables can leave scope: Get_Output anchors
   --  the producer, and Set_Input retains the upstream source.

   package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
   package Reader is new Itklib.IO.Image_File_Reader (Img);
   package Writer is new Itklib.IO.Image_File_Writer (Img);
   package Blur is new Itklib.Filters.Smoothing.Discrete_Gaussian (Img, Img);
   package Median is new Itklib.Filters.Smoothing.Median (Img, Img);
   package Thresh is new Itklib.Filters.Thresholding.Binary_Threshold (Img, Img);
   package Rescale is new Itklib.Filters.Image_Intensity.Rescale_Intensity (Img, Img);
   package Shrink is new Itklib.Filters.Image_Grid.Shrink (Img, Img);
   package Resample is new Itklib.Filters.Image_Grid.Resample (Img, Img);
   package Flip is new Itklib.Filters.Image_Grid.Flip (Img);
   package Crop is new Itklib.Filters.Image_Grid.Extract (Img, Img);
   package Edge is new Itklib.Filters.Image_Gradient.Gradient_Magnitude (Img, Img);
   package Erode is new Itklib.Filters.Morphology.Grayscale_Erode (Img, Img);
   package Dilate is new Itklib.Filters.Morphology.Grayscale_Dilate (Img, Img);
   package Otsu is new Itklib.Filters.Thresholding.Otsu_Threshold (Img, Img);
   package Grow is new Itklib.Filters.Region_Growing.Connected_Threshold (Img, Img);

   function Apply
     (Op : Adaimg_Command.Operation; Current : Img.Image) return Img.Image
   is
   begin
      case Op.Kind is
         when Adaimg_Command.Blur =>
            declare
               F : Blur.Filter := Blur.Create;
               Sigma_2 : constant Long_Float := Op.Sigma * Op.Sigma;
            begin
               F.Set_Input (Current);
               F.Set_Variance ((Sigma_2, Sigma_2));
               return F.Get_Output;
            end;
         when Adaimg_Command.Median =>
            declare
               F : Median.Filter := Median.Create;
            begin
               F.Set_Input (Current);
               F.Set_Radius ((Op.Radius, Op.Radius));
               return F.Get_Output;
            end;
         when Adaimg_Command.Threshold =>
            declare
               F : Thresh.Filter := Thresh.Create;
            begin
               F.Set_Input (Current);
               F.Set_Lower_Threshold (Op.Low);
               F.Set_Upper_Threshold (Op.High);
               F.Set_Inside_Value (65_535.0);
               F.Set_Outside_Value (0.0);
               return F.Get_Output;
            end;
         when Adaimg_Command.Rescale =>
            declare
               F : Rescale.Filter := Rescale.Create;
            begin
               F.Set_Input (Current);
               F.Set_Output_Minimum (Op.Low);
               F.Set_Output_Maximum (Op.High);
               return F.Get_Output;
            end;
         when Adaimg_Command.Resize_Shrink =>
            declare
               F : Shrink.Filter := Shrink.Create;
            begin
               F.Set_Input (Current);
               F.Set_Shrink_Factors ((Op.Shrink_Factor, Op.Shrink_Factor));
               return F.Get_Output;
            end;
         when Adaimg_Command.Resize_Resample =>
            declare
               F : Resample.Filter := Resample.Create;
            begin
               --  The input size is not known until Update. The filter
               --  applies the scale in GenerateOutputInformation.
               F.Set_Input (Current);
               F.Set_Uniform_Scale (Op.Scale);
               return F.Get_Output;
            end;
         when Adaimg_Command.Resize_Copy =>
            return Current;
         when Adaimg_Command.Flip =>
            declare
               F : Flip.Filter := Flip.Create;
               Axes : Flip.Axis_Flags := (others => False);
            begin
               Axes (Op.Flip_Axis) := True;
               F.Set_Input (Current);
               F.Set_Flip_Axes (Axes);
               return F.Get_Output;
            end;
         when Adaimg_Command.Crop =>
            declare
               F : Crop.Filter := Crop.Create;
               Region : constant Img.Region :=
                 (Start =>
                    (Interfaces.Integer_64 (Op.Crop_X),
                     Interfaces.Integer_64 (Op.Crop_Y)),
                  Extent =>
                    (Interfaces.Unsigned_64 (Op.Crop_W),
                     Interfaces.Unsigned_64 (Op.Crop_H)));
            begin
               F.Set_Input (Current);
               F.Set_Extraction_Region (Region);
               return F.Get_Output;
            end;
         when Adaimg_Command.Edge =>
            declare
               F : Edge.Filter := Edge.Create;
            begin
               F.Set_Input (Current);
               return F.Get_Output;
            end;
         when Adaimg_Command.Erode =>
            declare
               F : Erode.Filter := Erode.Create;
            begin
               F.Set_Input (Current);
               F.Set_Radius ((Op.Radius, Op.Radius));
               return F.Get_Output;
            end;
         when Adaimg_Command.Dilate =>
            declare
               F : Dilate.Filter := Dilate.Create;
            begin
               F.Set_Input (Current);
               F.Set_Radius ((Op.Radius, Op.Radius));
               return F.Get_Output;
            end;
         when Adaimg_Command.Otsu =>
            declare
               F : Otsu.Filter := Otsu.Create;
            begin
               F.Set_Input (Current);
               F.Set_Inside_Value (65_535.0);
               F.Set_Outside_Value (0.0);
               return F.Get_Output;
            end;
         when Adaimg_Command.Grow =>
            declare
               F : Grow.Filter := Grow.Create;
               Seed : constant Img.Index :=
                 (Interfaces.Integer_64 (Op.Seed_X),
                  Interfaces.Integer_64 (Op.Seed_Y));
            begin
               F.Set_Input (Current);
               F.Set_Lower (Op.Low);
               F.Set_Upper (Op.High);
               F.Set_Replace_Value (65_535.0);
               F.Set_Seed (Seed);
               return F.Get_Output;
            end;
         when Adaimg_Command.Canny =>
            raise Itklib.Itk_Error with
              "Canny needs float32. Run tools/add_pixel_type.py --pixel float32 --dims 2,3 and rebuild.";
      end case;
   end Apply;

   procedure Put_Mean (Value : Long_Float) is
   begin
      Ada.Long_Float_Text_IO.Put (Value, Fore => 1, Aft => 4, Exp => 0);
   end Put_Mean;

   function Plain (Value : Interfaces.Unsigned_64) return String is
      Text : constant String := Interfaces.Unsigned_64'Image (Value);
   begin
      if Text'Length > 0 and then Text (Text'First) = ' ' then
         return Text (Text'First + 1 .. Text'Last);
      end if;
      return Text;
   end Plain;

   package Stats_Filter is new Itklib.Filters.Image_Statistics.Statistics (Img);

   procedure Run_Identify (Path : String) is
      Input : Reader.Filter := Reader.Create;
      Stats : Stats_Filter.Filter := Stats_Filter.Create;
   begin
      Input.Set_File_Name (Path);
      Stats.Set_Input (Input.Get_Output);
      Stats.Update;
      declare
         Image : constant Img.Image := Input.Get_Output;
         Region : constant Img.Region := Img.Largest_Possible_Region (Image);
         Space : constant Img.Vector := Image.Spacing;
      begin
         Ada.Text_IO.Put (Path);
         Ada.Text_IO.Put (" PNG 2D ");
         Ada.Text_IO.Put (Plain (Region.Extent (1)));
         Ada.Text_IO.Put ("x");
         Ada.Text_IO.Put (Plain (Region.Extent (2)));
         Ada.Text_IO.Put (" UInt16 spacing ");
         Ada.Long_Float_Text_IO.Put (Space (1), Fore => 1, Aft => 6, Exp => 0);
         Ada.Text_IO.Put ("x");
         Ada.Long_Float_Text_IO.Put (Space (2), Fore => 1, Aft => 6, Exp => 0);
         Ada.Text_IO.Put (" min");
         Ada.Text_IO.Put (Long_Integer'Image (Long_Integer (Stats.Minimum)));
         Ada.Text_IO.Put (" max");
         Ada.Text_IO.Put (Long_Integer'Image (Long_Integer (Stats.Maximum)));
         Ada.Text_IO.Put (" mean ");
         Put_Mean (Stats.Mean);
         Ada.Text_IO.New_Line;
      end;
   end Run_Identify;

   Args : Adaimg_Command.Arg_Array
     (1 .. Integer'Max (1, Ada.Command_Line.Argument_Count));
   Command : Adaimg_Command.Command;
begin
   if Ada.Command_Line.Argument_Count = 0
     or else Ada.Command_Line.Argument_Count > Adaimg_Command.Max_Args
   then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Adaimg_Command.Usage);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   for I in 1 .. Ada.Command_Line.Argument_Count loop
      if Ada.Command_Line.Argument (I)'Length > Adaimg_Command.Max_Path then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "argument is too long");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
      Args (I) :=
        Adaimg_Command.Texts.To_Bounded_String (Ada.Command_Line.Argument (I));
   end loop;
   Command :=
     Adaimg_Command.Parse (Args (1 .. Ada.Command_Line.Argument_Count));
   case Command.Mode is
      when Adaimg_Command.Help =>
         Ada.Text_IO.Put_Line (Adaimg_Command.Texts.To_String (Command.Message));
      when Adaimg_Command.Usage_Error =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Adaimg_Command.Texts.To_String (Command.Message));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      when Adaimg_Command.Identify =>
         Run_Identify (Adaimg_Command.Texts.To_String (Command.Input));
      when Adaimg_Command.Pipeline =>
         declare
            Input : Reader.Filter := Reader.Create;
            Current : Img.Image;
         begin
            Input.Set_File_Name (Adaimg_Command.Texts.To_String (Command.Input));
            Current := Input.Get_Output;
            for I in 1 .. Command.Count loop
               Current := Apply (Command.Ops (I), Current);
            end loop;
            declare
               Output : Writer.Filter := Writer.Create;
            begin
               Output.Set_Input (Current);
               Output.Set_File_Name
                 (Adaimg_Command.Texts.To_String (Command.Output));
               Output.Update;
            end;
         end;
   end case;
exception
   when Event : Itklib.Itk_Error | Itklib.Unsupported_Instantiation =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (Event));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Adaimg;
