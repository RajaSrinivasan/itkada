package body Adaimg_Command with SPARK_Mode => On is

   function Usage return String is
     ("usage:" & ASCII.LF &
      "  adaimg identify file.png" & ASCII.LF &
      "  adaimg in.png [options] out.png" & ASCII.LF &
      "options:" & ASCII.LF &
      "  -blur sigma          discrete gaussian, variance = sigma*sigma" & ASCII.LF &
      "  -median r            neighborhood radius on x and y" & ASCII.LF &
      "  -threshold lo:hi     inside 65535, outside 0" & ASCII.LF &
      "  -rescale lo:hi       output intensity range" & ASCII.LF &
      "  -resize N%           shrink when N<100 and 100/N is an integer;" & ASCII.LF &
      "                       otherwise resample with linear interpolation" & ASCII.LF &
      "  -flip x|y            flip that axis (ITK origin follows the pixels)" & ASCII.LF &
      "  -crop WxH+X+Y        region index (X,Y), size (W,H), origin 0" & ASCII.LF &
      "  -edge                gradient magnitude (UInt16; not Canny)" & ASCII.LF &
      "  -erode r             grayscale erosion, ball radius r" & ASCII.LF &
      "  -dilate r            grayscale dilation, ball radius r" & ASCII.LF &
      "  -otsu                Otsu threshold, inside 65535, outside 0" & ASCII.LF &
      "  -grow x,y,lo:hi      connected threshold from seed (x,y)" & ASCII.LF &
      "  -canny sigma         Canny edges; needs generated float32");

   function To_Text (Value : String) return Texts.Bounded_String is
      Result : Texts.Bounded_String := Texts.Null_Bounded_String;
   begin
      if Value'Length > Max_Path then
         return Result;
      end if;
      Result := Texts.To_Bounded_String (Value);
      return Result;
   end To_Text;

   function Blank return Command is
     ((Mode => Usage_Error,
       Input => Texts.Null_Bounded_String,
       Output => Texts.Null_Bounded_String,
       Count => 0,
       Ops => [others => <>],
       Message => Texts.Null_Bounded_String));

   function Error (Text : String) return Command is
      Result : Command := Blank;
   begin
      Result.Mode := Usage_Error;
      Result.Message := To_Text (Text);
      return Result;
   end Error;

   type Number is record
      Ok : Boolean := False;
      Whole : Natural := 0;
      Value : Long_Float := 0.0;
   end record;

   function Parse_Number (Text : String) return Number with
     Global => null
   is
      Pos : Integer := Text'First;
      Whole : Natural := 0;
      Frac_Digits : Natural := 0;
      Frac_Scale : Natural := 1;
      Saw_Digit : Boolean := False;
      Saw_Dot : Boolean := False;
   begin
      if Text'Length = 0 or else Text'Length > 64 or else Text'Last = Integer'Last then
         return (Ok => False, Whole => 0, Value => 0.0);
      end if;
      while Pos <= Text'Last loop
         pragma Loop_Invariant (Pos in Text'First .. Text'Last + 1);
         pragma Loop_Invariant (Pos <= Integer'Last);
         pragma Loop_Invariant (Frac_Scale >= 1);
         pragma Loop_Variant (Increases => Pos);
         declare
            Ch : constant Character := Text (Pos);
            Digit : Natural;
         begin
            if Ch in '0' .. '9' then
               Digit := Character'Pos (Ch) - Character'Pos ('0');
               Saw_Digit := True;
               if not Saw_Dot then
                  if Whole > (1_000_000_000 - Digit) / 10 then
                     return (Ok => False, Whole => 0, Value => 0.0);
                  end if;
                  Whole := Whole * 10 + Digit;
               elsif Frac_Scale <= Natural'Last / 10
                 and then Frac_Digits <= (Natural'Last - Digit) / 10
               then
                  Frac_Scale := Frac_Scale * 10;
                  Frac_Digits := Frac_Digits * 10 + Digit;
               end if;
            elsif Ch = '.' and then not Saw_Dot then
               Saw_Dot := True;
            else
               return (Ok => False, Whole => 0, Value => 0.0);
            end if;
         end;
         Pos := Pos + 1;
      end loop;
      if not Saw_Digit or else Frac_Scale = 0 then
         return (Ok => False, Whole => 0, Value => 0.0);
      end if;
      return
        (Ok => True, Whole => Whole,
         Value => Long_Float (Whole) + Long_Float (Frac_Digits) / Long_Float (Frac_Scale));
   end Parse_Number;

   type Pair is record
      Ok : Boolean := False;
      Low : Long_Float := 0.0;
      High : Long_Float := 0.0;
   end record;

   function Range_Ends (Text : String) return Pair is
      Cut : Natural := 0;
   begin
      for I in Text'Range loop
         if Text (I) = ':' then
            Cut := I;
            exit;
         end if;
      end loop;
      if Cut <= Text'First or else Cut >= Text'Last then
         return (Ok => False, Low => 0.0, High => 0.0);
      end if;
      declare
         Left : constant Number := Parse_Number (Text (Text'First .. Cut - 1));
         Right : constant Number := Parse_Number (Text (Cut + 1 .. Text'Last));
      begin
         if not Left.Ok or else not Right.Ok then
            return (Ok => False, Low => 0.0, High => 0.0);
         end if;
         return (Ok => True, Low => Left.Value, High => Right.Value);
      end;
   end Range_Ends;

   function Parse (Args : Arg_Array) return Command is
      Result : Command := Blank;
      Index : Positive;
      Last : constant Integer := Args'Last;
   begin
      if Args'Length = 0 then
         return Error (Usage);
      end if;
      declare
         Head : constant String := Texts.To_String (Args (Args'First));
      begin
         if Head in "-h" | "--help" | "help" then
            Result.Mode := Help;
            Result.Message := To_Text (Usage);
            return Result;
         end if;
         if Head = "identify" then
            if Args'Length /= 2 then
               return Error ("identify needs one PNG path");
            end if;
            Result.Mode := Identify;
            Result.Input := Args (Args'First + 1);
            return Result;
         end if;
      end;

      if Args'Length < 2 then
         return Error (Usage);
      end if;

      Result.Mode := Pipeline;
      Result.Input := Args (Args'First);
      Result.Output := Args (Last);
      Index := Args'First + 1;
      while Index < Last loop
         pragma Loop_Invariant (Index in Args'Range);
         pragma Loop_Invariant (Result.Count <= Max_Ops);
         pragma Loop_Variant (Increases => Index);
         declare
            Token : constant String := Texts.To_String (Args (Index));
            Op : Operation;
         begin
            if Result.Count = Max_Ops then
               return Error ("too many operations");
            end if;
            if Token = "-blur" or else Token = "-median" or else Token = "-threshold"
              or else Token = "-rescale" or else Token = "-resize"
              or else Token = "-flip" or else Token = "-crop"
              or else Token = "-erode" or else Token = "-dilate"
              or else Token = "-grow" or else Token = "-canny"
            then
               if Index + 1 >= Last then
                  return Error ("missing argument for " & Token);
               end if;
               declare
                  Arg : constant String := Texts.To_String (Args (Index + 1));
               begin
                  if Token = "-blur" then
                     declare
                        Number : constant Adaimg_Command.Number := Parse_Number (Arg);
                     begin
                        if not Number.Ok or else Number.Value <= 0.0 then
                           return Error ("-blur needs a positive sigma");
                        end if;
                        Op.Kind := Blur;
                        Op.Sigma := Number.Value;
                     end;
                  elsif Token = "-median" then
                     declare
                        Number : constant Adaimg_Command.Number := Parse_Number (Arg);
                     begin
                        if not Number.Ok or else Number.Value /= Long_Float (Number.Whole) then
                           return Error ("-median needs an integer radius");
                        end if;
                        Op.Kind := Median;
                        Op.Radius := Number.Whole;
                     end;
                  elsif Token = "-threshold" or else Token = "-rescale" then
                     declare
                        Ends : constant Pair := Range_Ends (Arg);
                     begin
                        if not Ends.Ok or else Ends.Low > Ends.High then
                           return Error (Token & " needs lo:hi");
                        end if;
                        Op.Low := Ends.Low;
                        Op.High := Ends.High;
                        if Token = "-threshold" then
                           Op.Kind := Threshold;
                        else
                           Op.Kind := Rescale;
                        end if;
                     end;
                  elsif Token = "-resize" then
                     if Arg'Length < 2 or else Arg (Arg'Last) /= '%' then
                        return Error ("-resize needs N%");
                     end if;
                     declare
                        Number : constant Adaimg_Command.Number :=
                          Parse_Number (Arg (Arg'First .. Arg'Last - 1));
                     begin
                        if not Number.Ok or else Number.Whole = 0
                          or else Number.Value /= Long_Float (Number.Whole)
                        then
                           return Error ("-resize needs a positive integer percent");
                        end if;
                        if Number.Whole = 100 then
                           Op.Kind := Resize_Copy;
                        elsif Number.Whole < 100 and then 100 rem Number.Whole = 0 then
                           Op.Kind := Resize_Shrink;
                           Op.Shrink_Factor := 100 / Number.Whole;
                        else
                           Op.Kind := Resize_Resample;
                           Op.Scale := Long_Float (Number.Whole) / 100.0;
                        end if;
                     end;
                  elsif Token = "-erode" or else Token = "-dilate" then
                     declare
                        Number : constant Adaimg_Command.Number := Parse_Number (Arg);
                     begin
                        if not Number.Ok or else Number.Value /= Long_Float (Number.Whole) then
                           return Error (Token & " needs an integer radius");
                        end if;
                        if Token = "-erode" then
                           Op.Kind := Erode;
                        else
                           Op.Kind := Dilate;
                        end if;
                        Op.Radius := Number.Whole;
                     end;
                  elsif Token = "-canny" then
                     declare
                        Number : constant Adaimg_Command.Number := Parse_Number (Arg);
                     begin
                        if not Number.Ok or else Number.Value <= 0.0 then
                           return Error ("-canny needs a positive sigma");
                        end if;
                        Op.Kind := Canny;
                        Op.Sigma := Number.Value;
                     end;
                  elsif Token = "-grow" then
                     declare
                        Comma_1 : Natural := 0;
                        Comma_2 : Natural := 0;
                     begin
                        for I in Arg'Range loop
                           if Arg (I) = ',' then
                              if Comma_1 = 0 then
                                 Comma_1 := I;
                              elsif Comma_2 = 0 then
                                 Comma_2 := I;
                              end if;
                           end if;
                        end loop;
                        if Comma_1 <= Arg'First or else Comma_2 <= Comma_1
                          or else Comma_2 >= Arg'Last
                        then
                           return Error ("-grow needs x,y,lo:hi");
                        end if;
                        declare
                           X : constant Number :=
                             Parse_Number (Arg (Arg'First .. Comma_1 - 1));
                           Y : constant Number :=
                             Parse_Number (Arg (Comma_1 + 1 .. Comma_2 - 1));
                           Ends : constant Pair :=
                             Range_Ends (Arg (Comma_2 + 1 .. Arg'Last));
                        begin
                           if not X.Ok or else not Y.Ok or else not Ends.Ok
                             or else Ends.Low > Ends.High
                             or else X.Value /= Long_Float (X.Whole)
                             or else Y.Value /= Long_Float (Y.Whole)
                           then
                              return Error ("-grow needs x,y,lo:hi");
                           end if;
                           Op.Kind := Grow;
                           Op.Seed_X := X.Whole;
                           Op.Seed_Y := Y.Whole;
                           Op.Low := Ends.Low;
                           Op.High := Ends.High;
                        end;
                     end;
                  elsif Token = "-flip" then
                     if Arg'Length /= 1 or else Arg (Arg'First) not in 'x' | 'X' | 'y' | 'Y' then
                        return Error ("-flip needs x or y");
                     end if;
                     Op.Kind := Flip;
                     if Arg (Arg'First) in 'y' | 'Y' then
                        Op.Flip_Axis := 2;
                     else
                        Op.Flip_Axis := 1;
                     end if;
                  else
                     declare
                        X_At : Natural := 0;
                        Plus_1 : Natural := 0;
                        Plus_2 : Natural := 0;
                     begin
                        for I in Arg'Range loop
                           if Arg (I) = 'x' and then X_At = 0 then
                              X_At := I;
                           elsif Arg (I) = '+' then
                              if Plus_1 = 0 then
                                 Plus_1 := I;
                              elsif Plus_2 = 0 then
                                 Plus_2 := I;
                              end if;
                           end if;
                        end loop;
                        if X_At <= Arg'First or else Plus_1 <= X_At
                          or else Plus_2 <= Plus_1 or else Plus_2 >= Arg'Last
                        then
                           return Error ("-crop needs WxH+X+Y");
                        end if;
                        declare
                           W : constant Number :=
                             Parse_Number (Arg (Arg'First .. X_At - 1));
                           H : constant Number :=
                             Parse_Number (Arg (X_At + 1 .. Plus_1 - 1));
                           X : constant Number :=
                             Parse_Number (Arg (Plus_1 + 1 .. Plus_2 - 1));
                           Y : constant Number :=
                             Parse_Number (Arg (Plus_2 + 1 .. Arg'Last));
                        begin
                           if not W.Ok or else not H.Ok or else not X.Ok or else not Y.Ok
                             or else W.Whole = 0 or else H.Whole = 0
                             or else W.Value /= Long_Float (W.Whole)
                             or else H.Value /= Long_Float (H.Whole)
                             or else X.Value /= Long_Float (X.Whole)
                             or else Y.Value /= Long_Float (Y.Whole)
                           then
                              return Error ("-crop needs WxH+X+Y");
                           end if;
                           Op.Kind := Crop;
                           Op.Crop_W := W.Whole;
                           Op.Crop_H := H.Whole;
                           Op.Crop_X := X.Whole;
                           Op.Crop_Y := Y.Whole;
                        end;
                     end;
                  end if;
                  Index := Index + 2;
               end;
            elsif Token = "-edge" then
               Op.Kind := Edge;
               Index := Index + 1;
            elsif Token = "-otsu" then
               Op.Kind := Otsu;
               Index := Index + 1;
            else
               return Error ("unknown option " & Token);
            end if;
            Result.Count := Result.Count + 1;
            Result.Ops (Result.Count) := Op;
         end;
      end loop;
      return Result;
   end Parse;

end Adaimg_Command;
